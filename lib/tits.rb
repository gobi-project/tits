# encoding: utf-8

# Thinning System. Thins out the data sets stored in the database over time.
module TITS
  require 'influxdb'
  require 'active_record'
  require 'active_support/time'
  require 'active_support/core_ext'
  require 'yaml'

  unless defined? Rails
    # Dummy Rails module in case TITS is used in a no-Rails environment
    module Rails
      class << self
        def root
          File.expand_path('../..', __FILE__)
        end

        def env
          'development'
        end
      end
    end
  end

  attr_reader :notify

  module_function
  # Establishes global conncection to InfluxDB read from config.
  #
  # @return an InfluxDB::Client object
  def influx
    return @influx if @influx

    influx_config = YAML.load_file("#{Rails.root}/config/config.yml") \
                    ['influxdb'][Rails.env]

    @influx = InfluxDB::Client.new influx_config['db_name'],
                                   username:       influx_config['db_user'],
                                   password:       influx_config['db_pw'],
                                   host:           influx_config['host'],
                                   port:           influx_config['port'],
                                   time_precision: 'm'
  end

  # Returns the on_write block.
  #
  # @return [Block] the block that is exectued after each write
  def notify
  @notify
  end

  # Sets the block to be called after a new measurement has been added.
  #
  # @param notify [Block] a block to which the MeasurementDTO object is passed.
  #                       Useful for e.g. Websockets.
  def on_write(&notify)
    @notify = notify
  end

  # Deletes the whole InfluxDB database.
  def delete_db
    influx_config = YAML.load_file("#{Rails.root}/config/config.yml") \
                    ['influxdb'][Rails.env]
    influx.delete_database influx_config['db_name']
  end

  # Removes a specific series (=a resource's measurements) from the
  # InfluxDB database.
  #
  # @param resource_id [Integer] the resource ID of the series
  def delete_series(resource_id)
    TITS.influx.query("delete from r#{resource_id}")
  end

  # Request the most recent measurement (each) from multiple resources.
  #
  # @param ids [Integer] or [Integer Array] (optional)
  #               the resource ID(s).
  #               If omitted, measurements from every resource are returned.
  # @return an Array of Measurement objects in the same order.
  def multi_current_measurements(ids = nil)
    measurements = []

    # Query most recent measurement from every resource
    result = TITS.influx.query('select value from /.*/ limit 1;')

    if result && !result.empty?

      # No IDs given, return measurements for all resources:
      if ids.nil?

        result.each do |resource, measurement|
          id = resource[1, resource.length]

          value = measurement.first['value']
          time = Time.at(measurement.first['time'] / 1000)
          measurements.push Measurement.new(id.to_i, value, time)
        end

      else

        ids = ids.is_a?(Array) ? ids : [ids]  # Convert to array if single ID
        ids = ids.uniq  # Eliminate duplicate IDs

        # Try to find a result for each ID
        ids.each do |id|
          next unless result["r#{id}"]

          value = result["r#{id}"].first['value']
          time = Time.at(result["r#{id}"].first['time'] / 1000)
          measurements.push Measurement.new(id, value, time)
        end

      end

    end

    measurements
  end

  # Imitates important methods of ActiveRecord::Base,
  # adding special methods for querying (thinned) values.
  class Base < ActiveRecord::Base
    self.abstract_class = true

    require 'tits/models/measurement'

    # Adds a new value for this resource using the specified date/time.
    #
    # @param value [Float] the value to be added.
    # @param time [Time] the optional date/time. Default is Time.now.
    def add_measurement(value, time = Time.now)
      TITS.influx.write_point("r#{id}", time: time.to_i * 1000, value: value)

      # Construct the DTO object and pass it to the block
      dto = MeasurementDTO.new
      dto.resource_id = id
      dto.value = value
      dto.time = time

      TITS.notify.call(dto) if TITS.notify
    end

    # Query the measurement closest to a given time.
    # If there is no measurement in a 20 minute range around the given time,
    # nil is returned.
    #
    # @param time [Time] the time.
    # @param options [Hash] an optional hash containing options.
    #  that change/extend the return value.
    # @return a Measurement object containing time + value or nil
    #         if no close value can be found.
    def measurement(time, options = {})
      time = time.to_i # Convert to UNIX time

      # Time range
      start_point = (time - 10.minute.to_i)
      end_point = (time + 10.minute.to_i)

      result = TITS.influx.query("select value from r#{id} where \
                                  time > #{start_point}s and \
                                  time < #{end_point}s;")["r#{id}"]

      return unless result && !result.empty?

      result = result.sort! do |e1, e2|
        (e1['time'] - time * 1000).abs <=> (e2['time'] - time * 1000).abs
      end

      result = result.first
      value = result['value']
      time = Time.at(result['time'] / 1000)
      Measurement.new(id, value, time)
    end

    # Query the current (actually the most recent) measurement.
    #
    # @param options (see TITS::Base.measurement).
    # @return a Measurement object containing time + value.
    def current_measurement(options = {})
      result = TITS.influx.query("select value from r#{id} limit 1;")["r#{id}"]

      return unless (result && !result.empty?)

      result = result.first
      value = result['value']
      time = Time.at(result['time'] / 1000)
      Measurement.new(id, value, time)
    end

    # Query multiple measurements from a given time range.
    #
    # @param options (see TITS::Base.measurement).
    # => granularity [Integer] the optional desired granularity of the returned
    # value in seconds. Usage of active_support/time helpers is encouraged
    # (e.g. 1.day or 3.months). Default is 1.hour.
    # => start_point [Time] an optional start point of the time range from
    #    which the measurements are to be queried. Default is the year 1970.
    # => end_point [Time] an optional end point of the time range
    #    from which the measurements are to be queried. Default is Time.now.
    # @return a list of Measurement objects containing time + value.
    def measurements(options = {})
      options.reverse_merge! start_point: Time.at(0), granularity: 1.hour,
                             end_point: Time.now

      # Convert time range to UTC timezone in UNIX time
      start_point = options[:start_point].utc.to_i
      end_point =  options[:end_point].utc.to_i

      # Convert granularity to seconds
      granularity = options[:granularity].to_i

      result = TITS.influx.query("select mean(value) from r#{id} where \
                                  time > #{start_point}s and \
                                  time < #{end_point}s \
                                  group by time(#{granularity}s);")

      return unless result && !result.empty?

      result["r#{id}"].map! do |m|
        Measurement.new(id, m['mean'], Time.at(m['time'] / 1000))
      end
    end

    # Query all measurements since a give point of time.
    #
    # @param options (see TITS::Base.measurements)
    # @return (see TITS::Base.measurements)
    def measurements_since(start_point, options = {})
      if options[:granularity].nil?
        measurements(start_point: start_point)
      else
        measurements(start_point: start_point,
                     granularity: options[:granularity])
      end
    end

    # Query the measurement with maximum value from a given time range.
    #
    # @param options (see TITS::Base.measurement).
    # => start_point [Time] an optional start point of the time range from
    #    which the measurements are to be queried. Default is the year 1970.
    # => end_point [Time] an optional end point of the time range
    #    from which the measurements are to be queried. Default is Time.now.
    # @return a Measurement object containing time + maximum value.
    def max_measurement(options = {})
      options.reverse_merge! start_point: Time.at(0), end_point: Time.now

      # Convert time range to UTC timezone in UNIX time
      start_point = options[:start_point].utc.to_i
      end_point =  options[:end_point].utc.to_i

      result = TITS.influx.query("select max(value) from r#{id} where \
                                  time > #{start_point}s and \
                                  time < #{end_point}s;")

      return unless result && !result.empty?

      result = result["r#{id}"].first
      value = result['max']
      time = Time.at(result['time'] / 1000)
      Measurement.new(id, value, time)
    end

    # Query the measurement with minimum value from a given time range.
    #
    # @param (see TITS::Base.max_measurement)
    # @return a Measurement object containing time + minimum value.
    def min_measurement(options = {})
      options.reverse_merge! start_point: Time.at(0), end_point: Time.now

      # Convert time range to UTC timezone in UNIX time
      start_point = options[:start_point].utc.to_i
      end_point =  options[:end_point].utc.to_i

      result = TITS.influx.query("select min(value) from r#{id} where \
                                  time > #{start_point}s and \
                                  time < #{end_point}s;")

      return unless result && !result.empty?

      result = result["r#{id}"].first
      value = result['min']
      time = Time.at(result['time'] / 1000)
      Measurement.new(id, value, time)
    end

    # Query the average value from a given time range.
    #
    # @param (see TITS::Base.max_measurement)
    # @return a Measurement object containing the average value.
    #         Time is omitted.
    def avg_measurement(options = {})
      options.reverse_merge! start_point: Time.at(0), end_point: Time.now

      # Convert time range to UTC timezone in UNIX time
      start_point = options[:start_point].utc.to_i
      end_point =  options[:end_point].utc.to_i

      result = TITS.influx.query("select mean(value) from r#{id} where \
                                  time > #{start_point}s and \
                                  time < #{end_point}s;")

      return unless result && !result.empty?

      result = result["r#{id}"].first
      value = result['mean']
      Measurement.new(id, value, nil)
    end

    # Removes the series (=measurements) belonging to this resource
    # from the InfluxDB database.
    def delete_series
      TITS.delete_series id
    end
  end
end

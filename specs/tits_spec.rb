require 'minitest_helper'

describe TITS::Base do

  before do
    @r = Resource.new 'test'
    @r.delete_series

    # Value + time used for testing
    @value = 163.96
    @value2 = 71.4
    @values = rnd_values
    @time = Time.new(2002, 10, 31, 2, 0, 0)
    @time2 = Time.new(2002, 10, 31, 1, 0, 0) # 1h before
  end

  describe 'when db is empty' do

    it 'must not contain any measurements' do
      @r.current_measurement.must_be_nil
      @r.measurement(Time.now).must_be_nil
      @r.measurements.must_be_nil
      @r.measurements_since(Time.now - 10.hours).must_be_nil
      @r.max_measurement.must_be_nil
      @r.min_measurement.must_be_nil
      @r.avg_measurement.must_be_nil
    end

  end

  describe 'measurement' do

    it 'can be added and consequently appears in InfluxDB' do
      @r.add_measurement @value, @time
      @r.current_measurement.value.must_equal @value
      @r.current_measurement.time.must_equal @time
    end

    it 'can be added without explicit time' do
      @r.add_measurement @value
      @r.current_measurement.value.must_equal @value
    end

    it 'can be queried (closest to given time)' do
      @r.add_measurement @value, @time
      @r.add_measurement @value2, @time2

      # Exact time
      @r.measurement(@time).value.must_equal @value
      @r.measurement(@time2).value.must_equal @value2

      # Pretty close
      @r.measurement(@time - 9.minutes).value.must_equal @value
      @r.measurement(@time - 9.minutes).time.must_equal @time

      # Not close enough
      @r.measurement(@time - 11.minutes).must_be_nil

      # Close, but to another time
      @r.measurement(@time - 55.minutes).value.must_equal @value2
      @r.measurement(@time - 55.minutes).time.must_equal @time2
    end

  end

  describe 'max measurement' do

    it 'can be queried' do
      @values.each do |v|
        @r.add_measurement v, @time
      end
      @r.max_measurement.value.must_equal @values.max
    end

    # TODO: time constraints

  end

  describe 'min measurement' do

    it 'can be queried' do
      @values.each do |v|
        @r.add_measurement v, @time
      end
      @r.min_measurement.value.must_equal @values.min
    end

    # TODO: time constraints

  end

  describe 'average measurement' do

    it 'can be queried' do
      @values.each do |v|
        @r.add_measurement v, @time
      end
      @r.avg_measurement.value.round(2).must_equal((@values.inject(:+).to_f / @values.size).round(2))
    end

    # TODO: time constraints

  end

  describe 'measurements since given time' do

    it 'can be queried' do
      @r.add_measurement @value, @time
      @r.add_measurement @value2, @time2
      @r.measurements_since(@time - 10.minutes).size.must_equal 1
      @r.measurements_since(@time - 10.minutes).first.value.must_equal @value
    end

  end

  # TODO: granularity, delete_series, multiple measurements, ...

end

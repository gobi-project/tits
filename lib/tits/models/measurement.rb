# The Measurement model for storing ID, time and value.
class Measurement
  attr_accessor :resource_id
  attr_accessor :time
  attr_accessor :value

  # Creates a new measurement.
  #
  # @param resource_id [Integer] the ID of the new measurement.
  # @param value [Integer] the value of the measurement.
  # @param time [Time] the time at which the measurement was taken.
  #                           Optional. Defaults to Time.now.
  def initialize(resource_id, value, time = Time.now)
    @resource_id = resource_id
    @value = value
    @time = time
  end
end

# A Data Transfer Object for Measurment objects. Used for the callback / notify.
class MeasurementDTO
  attr_accessor :resource_id, :value, :time
end

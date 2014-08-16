# A simple example implementation of a Resource model.
class Resource < TITS::Base
  attr_accessor :id

  # Creates a new resource.
  # Establishes connection to Influx database upon initialization
  #
  # @param resource_id [Integer] the ID of the new resource.
  def initialize(resource_id)
    @id = resource_id
  end
end

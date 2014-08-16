require 'minitest/autorun'
require 'tits'
require 'tits/models/resource'

def rnd_values
  values = []
  13.times do
    values.push rnd_from_range(-27.1, 173.4).round(2)
  end
  values
end

def rnd_from_range(from, to)
  rand * (to - from) + from
end

Gem::Specification.new do |s|
  s.name        = 'tits'
  s.version     = '0.0.2.pre'
  s.date        = '2014-04-29'
  s.summary     = 'TITS - Time Interval Thinning System'
  s.description = 'A Time Interval Thinning System...'
  s.authors     = ['GOBI', 'Stephan Brinkmann']
  s.email       = ['gobi@tzi.de', 'sbrink@tzi.de']
  s.files       = Dir.glob('lib/*.rb') + Dir.glob('lib/tits/*.rb') +
                  Dir.glob('lib/tits/models/*.rb') +
                  Dir.glob('config/config.yml')
  s.homepage    = 'http://gobi.tzi.de'
  s.license     = 'MIT'
  s.test_files  = ['specs/tits_spec.rb']
  s.add_dependency 'activerecord'
  s.add_dependency 'yard'
  s.add_dependency 'redcarpet'
  s.add_dependency 'influxdb'
end

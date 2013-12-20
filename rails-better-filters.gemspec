$:.unshift File.expand_path('../lib', __FILE__)
require 'rails-better-filters/version'

Gem::Specification.new do |s|
  s.name          = 'rails-better-filters'
  s.version       = RailsBetterFilters::VERSION
# TODO
#  s.license       = 'MIT'
  s.summary       = 'Better filters for your Rails controllers'
  s.description   = 'Better filters for your Rails controllers'

  s.authors       = ['FlavourSys Technology GmbH']
  s.email         = 'technology@flavoursys.com'
  s.homepage      = 'http://gitlab.flavoursys.lan/internal/rails-better-filters'

  s.require_paths = ['lib']
  s.files         = Dir.glob('lib/**/*.rb')

  s.add_development_dependency 'rspec'
end

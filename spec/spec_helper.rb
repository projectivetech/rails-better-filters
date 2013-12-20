require 'rspec'
require 'rails-better-filters'

Dir["#{File.expand_path('..', __FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.order = 'random'
end

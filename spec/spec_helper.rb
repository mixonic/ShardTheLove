require 'rubygems'
require 'spec'
require 'lib/shard'

require 'mocha'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

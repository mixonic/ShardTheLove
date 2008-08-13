require 'rubygems'
require 'spec'
require 'lib/shard_the_love'

require 'mocha'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

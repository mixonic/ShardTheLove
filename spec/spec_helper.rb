require 'rubygems'
require 'spec'
require 'lib/shard_the_love'

require 'mocha'

Spec::Runner.configure do |config|
  config.mock_with :mocha

  config.before(:all) do
    unless Object.const_defined?(:CONFIG_RUN)
      ShardTheLove::LOGGER = stub(:info => true )
      ShardTheLove::ENV = 'test'
      CONFIG_RUN = true
    end
  end

end

# Set up some ENV for merb/rails compatibility, load the library

require File.dirname(__FILE__) + '/lib/active_record/base'
require File.dirname(__FILE__) + '/lib/shard_the_love'

if defined?(Rails)
  ShardTheLove::ROOT = RAILS_ROOT
  ShardTheLove::ENV = RAILS_ENV
elsif defined?(Merb)
  ShardTheLove::ROOT = Merb.root
  ShardTheLove::ENV = (Merb.env == 'rake' ? 'development' : Merb.env)
end


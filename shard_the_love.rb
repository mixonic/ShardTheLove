# Set up some ENV for merb/rails compatibility, load the library

reqire 'active_record/connection_adapters/abstract/schema_statements'
require File.dirname(__FILE__) + '/lib/active_record/connection_adapters/abstract/schema_statements'
require File.dirname(__FILE__) + '/lib/shard_the_love'

if defined?(Rails)
  ShardTheLove::ROOT = RAILS_ROOT
  ShardTheLove::ENV = RAILS_ENV
  ShardTheLove::LOGGER = Rails.logger
  ShardTheLove::DB_PATH = 'db/'
  ShardTheLove::RAKE_ENV_SETUP = :environment
elsif defined?(Merb)
  ShardTheLove::ROOT = Merb.root
  ShardTheLove::ENV = (Merb.env == 'rake' ? 'development' : Merb.env)
  ShardTheLove::LOGGER = Merb.logger
  ShardTheLove::DB_PATH = 'schema/'
  ShardTheLove::RAKE_ENV_SETUP = :merb_start
end


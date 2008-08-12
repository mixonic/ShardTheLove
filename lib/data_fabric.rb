require 'active_record'
require 'active_record/version'

# DataFabric adds a new level of flexibility to ActiveRecord connection handling.
# You need to describe the topology for your database infrastructure in your model(s).  As with ActiveRecord normally, different models can use different topologies.
# 
# class MyHugeVolumeOfDataModel < ActiveRecord::Base
#   data_fabric :replicated => true, :shard_by => :city
# end
# 
# There are four supported modes of operation, depending on the options given to the data_fabric method.  The plugin will look for connections in your config/database.yml with the following convention:
# 
# No connection topology:
# #{environment} - this is the default, as with ActiveRecord, e.g. "production"
# 
# data_fabric :replicated => true
# #{environment}_#{role} - no sharding, just replication, where role is "master" or "slave", e.g. "production_master"
# 
# data_fabric :shard_by => :city
# #{group}_#{shard}_#{environment} - sharding, no replication, e.g. "city_austin_production"
# 
# data_fabric :replicated => true, :shard_by => :city
# #{group}_#{shard}_#{environment}_#{role} - sharding with replication, e.g. "city_austin_production_master"
# 
# 
# When marked as replicated, all write and transactional operations for the model go to the master, whereas read operations go to the slave.
# 
# Since sharding is an application-level concern, your application must set the shard to use based on the current request or environment.  The current shard for a group is set on a thread local variable.  For example, you can set the shard in an ActionController around_filter based on the user as follows:
# 
# class ApplicationController < ActionController::Base
#   around_filter :select_shard
#   
#   private
#   def select_shard(&action_block)
#     DataFabric.activate_shard(:city => @current_user.city, &action_block)
#   end
# end
module DataFabric
  
  def self.logger
    ActiveRecord::Base.logger
  end

  def self.init
    logger.info "Loading data_fabric #{DataFabric::Version::STRING} with ActiveRecord #{ActiveRecord::VERSION::STRING}"
    ActiveRecord::Base.send(:include, self)
  end
  
  def self.clear_connection_pool!
    (Thread.current[:data_fabric_connections] ||= {}).clear
  end
  
  def self.activate_shard(shards, &block)
    ensure_setup

    # Save the old shard settings to handle nested activation
    old = Thread.current[:shards].dup

    shards.each_pair do |key, value|
      Thread.current[:shards][key.to_s] = value.to_s
    end
    if block_given?
      begin
        yield
      ensure
        Thread.current[:shards] = old
      end
    end
  end
  
  # For cases where you can't pass a block to activate_shards, you can
  # clean up the thread local settings by calling this method at the
  # end of processing
  def self.deactivate_shard(shards)
    ensure_setup
    shards.each do |key, value|
      Thread.current[:shards].delete(key.to_s)
    end
  end
  
  def self.active_shard(group)
    raise ArgumentError, 'No shard has been activated' unless Thread.current[:shards]

    returning(Thread.current[:shards][group.to_s]) do |shard|
      raise ArgumentError, "No active shard for #{group}" unless shard
    end
  end
  
  def self.included(model)
    # Wire up ActiveRecord::Base
    model.extend ClassMethods
  end

  def self.ensure_setup
    Thread.current[:shards] = {} unless Thread.current[:shards]
  end
  
  # Class methods injected into ActiveRecord::Base
  module ClassMethods
    def data_fabric
      proxy = DataFabric::ConnectionProxy.new(self)
      ActiveRecord::Base.active_connections[name] = proxy
      
      raise ArgumentError, "data_fabric does not support ActiveRecord's allow_concurrency = true" if allow_concurrency
      DataFabric.logger.info "Creating data_fabric proxy for class #{name}"
    end
    alias :connection_topology :data_fabric # legacy
  end
  
  def connection_name
    raise( 'A shard must be selected' ) unless @connection_name
    @connection_name
  end
  
  def use_directory
    @connection_name = 'directory'
    self
  end
  
  def use_shard( shard )
    @connection_name = shard
    self
  end
  
  class StringProxy
    def initialize(&block)
      @proc = block
    end
    def to_s
      @proc.call
    end
  end

  class ConnectionProxy
    def initialize(model_class)
      @model_class = model_class      
      @cached_connection = nil
      @current_connection_name = nil
      @role_changed = false

      @model_class.send :include, ActiveRecordConnectionMethods if @replicated
    end
    
    def transaction(start_db_transaction = true, &block)
      raw_connection.transaction(start_db_transaction, &block)
    end

    def method_missing(method, *args, &block)
      unless @cached_connection and !@role_changed
        raw_connection
        @role_changed = false
      end
      if logger.debug?
        logger.debug("Calling #{method} on #{@cached_connection}")
      end
      raw_connection.send(method, *args, &block)
    end
    
    def connection_name
      "#{RAILS_ENV}_#{@model_class.connection_name}"
    end
    
    def disconnect!
      @cached_connection.disconnect! if @cached_connection
      @cached_connection = nil
    end
    
    def verify!(arg)
      @cached_connection.verify!(0) if @cached_connection
    end
    
    def raw_connection
      conn_name = connection_name
      unless already_connected_to? conn_name 
        @cached_connection = begin 
          connection_pool = (Thread.current[:data_fabric_connections] ||= {})
          conn = connection_pool[conn_name]
          if !conn
            if logger.debug?
              logger.debug "Switching from #{@current_connection_name || "(none)"} to #{conn_name} (new connection)"
            end
            config = ActiveRecord::Base.configurations[conn_name]
            raise ArgumentError, "Unknown database config: #{conn_name}, have #{ActiveRecord::Base.configurations.inspect}" unless config
            @model_class.establish_connection config
            conn = @model_class.connection
            connection_pool[conn_name] = conn
          elsif logger.debug?
            logger.debug "Switching from #{@current_connection_name || "(none)"} to #{conn_name} (existing connection)"
          end
          @current_connection_name = conn_name
          conn.verify!(-1)
          conn
        end
        @model_class.active_connections[@model_class.name] = self
      end
      @cached_connection
    end

    private
    
    def already_connected_to?(conn_name)
      conn_name == @current_connection_name and @cached_connection
    end
    
    def logger
      DataFabric.logger
    end
  end

end

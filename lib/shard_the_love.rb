require 'active_record'
require 'active_record/version'
require 'active_record/connection_adapters/abstract/connection_specification'
require 'active_record/connection_adapters/abstract/connection_pool'

module ShardTheLove

  def self.directory_handler
    @@current_directory_connection || nil
  end

  def self.shard_handlers
    @@current_shard_connections || {}
  end

  @@current_shard_connections, @@current_directory_connection = {}, nil
  
  def self.logger
    LOGGER
  end

  def self.init
    self.logger.info "Loading ShardTheLove with ActiveRecord #{ActiveRecord::VERSION::STRING}" if self.logger
    ActiveRecord::Base.send(:include, self)
  end
  
  def self.with_shard(shard, &block)
    # Save the old shard settings to handle nested activation
    old = Thread.current[:shard].dup rescue false

    Thread.current[:shard] = shard
    if block_given?
      begin
        logger.info "STL: Switching scope to shard '#{shard}'"
        yield
      ensure
        Thread.current[:shard] = old if old
      end
    end
  end
 
  class << self
    alias :with :with_shard
  end
  
  # For cases where you can't pass a block to activate_shards, you can
  # clean up the thread local settings by calling this method at the
  # end of processing
  def self.deactivate_shard
    Thread.current.delete(:shard)
  end
  
  def self.current_shard
    returning(Thread.current[:shard]) do |shard|
      raise ArgumentError, "No active shard" unless shard
    end
  end

  def self.current_shard_connection( ar_class )
    if @@current_shard_connections[current_shard] &&
       @@current_shard_connections[current_shard].connected?(ar_class)
      # logger.info "STL: Existing connection for '#{ar_class}' to '#{current_shard}' - "+@@current_shard_connections[current_shard].connection_pools.keys.join(", ")
      return @@current_shard_connections[current_shard]
    end

    logger.info "STL: New connection for '#{ar_class}' to '#{current_shard}'"

    spec = ActiveRecord::Base.configurations[ar_class.config_key(RAILS_ENV)]
    
    raise 'Shard not configured' unless spec

    adapter_method = "#{spec['adapter']}_connection"

    @@current_shard_connections[current_shard] ||= ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    @@current_shard_connections[current_shard].establish_connection(
      ar_class.name,
      ActiveRecord::Base::ConnectionSpecification.new(
        spec,
        adapter_method
      )
    )

    return @@current_shard_connections[current_shard]
  end

  def self.current_directory_connection( ar_class )
    return @@current_directory_connection if @@current_directory_connection
    
    spec = ActiveRecord::Base.configurations[ar_class.config_key(RAILS_ENV)]

    raise 'Directory not configured' unless spec

    adapter_method = "#{spec['adapter']}_connection"

    @@current_directory_connection ||= ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    @@current_directory_connection.establish_connection(
      ar_class.name,
      ActiveRecord::Base::ConnectionSpecification.new(
        spec,
        adapter_method
      )
    )

    return @@current_directory_connection
  end
  
  def self.included(model)
    # Wire up ActiveRecord::Base
    model.extend ClassMethods
  end

  # Class methods injected into ActiveRecord::Base
  module ClassMethods
    
    def acts_as_shard
      class_eval 'def self.config_key(env); "#{env}_#{ShardTheLove.current_shard}"; end'
      class_eval 'def self.connection_handler; ShardTheLove.current_shard_connection(self); end'
      class_eval 'def connection_handler; self.class.connection_handler; end'
    end

    def acts_as_directory
      class_eval 'def self.config_key(env); "#{env}_directory"; end'
      class_eval 'def self.connection_handler; ShardTheLove.current_directory_connection(self); end'
      class_eval 'def connection_handler; self.class.connection_handler; end'
    end

  end

end

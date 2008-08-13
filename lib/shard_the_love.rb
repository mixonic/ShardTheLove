require 'active_record'
require 'active_record/version'

module ShardTheLove
  
  def self.logger
    ActiveRecord::Base.logger
  end

  def self.init
    logger.info "Loading data_fabric with ActiveRecord #{ActiveRecord::VERSION::STRING}"
    ActiveRecord::Base.send(:include, self)
  end
  
  def self.clear_connection_pool!
    (Thread.current[:shard_the_love_connections] ||= {}).clear
  end
  
  def self.with_shard(shard, &block)
    # Save the old shard settings to handle nested activation
    old = Thread.current[:shard].dup rescue false

    Thread.current[:shard] = shard
    if block_given?
      begin
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
  
  def self.included(model)
    # Wire up ActiveRecord::Base
    model.extend ClassMethods
  end

  # Class methods injected into ActiveRecord::Base
  module ClassMethods
    def acts_as_shard
      proxy = ShardTheLove::ConnectionProxy.new(self)
      ActiveRecord::Base.active_connections[name] = proxy
      
      raise ArgumentError, "data_fabric does not support ActiveRecord's allow_concurrency = true" if allow_concurrency
      ShardTheLove.logger.info "Creating data_fabric proxy for class #{name}"
    end

    def acts_as_directory
      self.acts_as_shard
      self.mark_as_directory
    end
     
    def connection_name
      return 'directory' if @@acting_as_directories && @@acting_as_directories.include?( self.to_s )
      raise( 'A shard must be selected' ) unless Thread.current[:shard]
      return Thread.current[:shard]
    end

    def mark_as_directory
      @@acting_as_directories ||= []
      @@acting_as_directories << self.to_s
    end
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
    end
    
    def transaction(start_db_transaction = true, &block)
      raw_connection.transaction(start_db_transaction, &block)
    end

    def method_missing(method, *args, &block)
      unless @cached_connection
        raw_connection
      end
      if logger.debug?
        logger.debug("Calling #{method} on #{@cached_connection}")
      end
      begin
        raw_connection.send(method, *args, &block)
      rescue ActiveRecord::StatementInvalid => e
        if e =~ /^Mysql::Error: MySQL server has gone away:/
          @cached_connection = nil
          raw_connection
          raw_connection.send(method, *args, &block)
        end
      end
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
          connection_pool = (Thread.current[:shard_the_love_connections] ||= {})
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
      ShardTheLove.logger
    end
  end

end


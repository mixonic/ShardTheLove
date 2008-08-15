require 'active_record'

module ActiveRecord
  
  class Base

  class << self
    alias :_establish_connection :establish_connection
  end
  
  def self.establish_connection( spec = nil )
    case spec
      when nil
        begin
          establish_connection( ShardTheLove::ENV )
        rescue AdapterNotSpecified
          establish_connection( ShardTheLove::ENV+'_directory' )
        end
      when String
        spec = spec.to_sym if Merb
        if configuration = configurations[spec]
          establish_connection(configuration)
        else
          raise AdapterNotSpecified, "#{spec} database is not configured"
        end
      else
        _establish_connection( spec )
    end
  end
  
  end

end

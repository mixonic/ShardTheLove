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
        establish_connection( spec )
      else
        _establish_connection( spec )
    end
  end
  
  end

end

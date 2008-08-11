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
          _establish_connection( RAILS_ENV )
        rescue AdapterNotSpecified
          _establish_connection( RAILS_ENV+'_directory' )
        end
      else
        _establish_connection( spec )
    end
  end
  
  end

end

require 'active_record'

class ActiveRecord::Base

  alias :_establish_connection :establish_connection
  def self.establish_connection( spec = nil )
    case spec
      when nil
        begin
          _establish_connection( spec )
        rescue AdaptedNotSpecified
          _establish_connection( spec+'_directory' )
        end
      else
        _establish_connection( spec )
    end
  end

end

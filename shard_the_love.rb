# Set up some ENV for merb/rails compatibility, load the library

if defined?(Rails)
  ROOT = RAILS_ROOT
  ENV = RAILS_ENV
elsif defined?(Merb)
  ROOT = Merb.root
  ENV = (Merb.env == 'rake' ? 'development' : Merb.env)
end

require File.dirname(__FILE__) + '/lib/active_record/base'
require File.dirname(__FILE__) + '/lib/shard_the_love'

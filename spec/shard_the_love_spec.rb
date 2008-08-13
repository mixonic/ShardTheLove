require File.join(File.dirname(__FILE__),'spec_helper')

describe ShardTheLove do

  it "should return a logger from ActiveRecord" do
    ActiveRecord::Base.expects(:logger)
    ShardTheLove.logger
  end

  it "should clear the connection pool" do
    Thread.current[:shard_the_love_connections] = {}
    Thread.current[:shard_the_love_connections].expects(:clear)
    ShardTheLove.clear_connection_pool!
  end

  it "should deactivate shards" do
    Thread.current.expects(:delete).with(:shard)
    ShardTheLove.deactivate_shard
  end

  it "should extent the model on inclusion" do
    class Shard; end
    Shard.expects(:extend)
    Shard.send( :include, ShardTheLove )
  end

end

describe ShardTheLove, "when using a shard" do

  it "should set the shard variable inside the block" do
    ShardTheLove.with_shard( 'hewey' ) do
      Thread.current[:shard].should == 'hewey'
    end
  end

  it "should set the shard variable inside a nested block" do
    ShardTheLove.with_shard( 'hewey' ) do
      ShardTheLove.with_shard( 'dewey' ) do
        Thread.current[:shard].should == 'dewey'
      end
    end
  end

  it "should set the old shard variable back inside a nested block" do
    ShardTheLove.with_shard( 'hewey' ) do
      ShardTheLove.with_shard( 'dewey' ) do
      end
      Thread.current[:shard].should == 'hewey'
    end
  end

  it "should leave the current shard variable if there is no old one to reset" do
    ShardTheLove.with_shard( 'hewey' ) do
    end
    Thread.current[:shard].should == 'hewey'
  end


end

describe ShardTheLove, "when getting the current_shard" do

  it "should return current thread variable" do
    Thread.current[:shard] = 'hewey'
    ShardTheLove.current_shard.should == 'hewey'
  end
  
  it "should raise ArgumentError if there is no current shard" do
    Thread.current[:shard] = nil
    lambda { ShardTheLove.current_shard }.should raise_error(ArgumentError, "No active shard")
  end

end

describe ShardTheLove, "when initializing" do
  
  it "should include itself into ActiveRecord on init" do
    ShardTheLove.logger.stubs(:info)
    ActiveRecord::Base.expects(:include).with(ShardTheLove)
  end

  it "should send a log message" do
    ShardTheLove.logger.expects(:info)
  end

  after(:each) do
    ShardTheLove.init
  end

end

describe ShardTheLove do

  before(:each) do
    ShardTheLove.init

    class Shard < ActiveRecord::Base
      acts_as_shard
    end

    class Directory < ActiveRecord::Base
      acts_as_directory
    end
  end

end


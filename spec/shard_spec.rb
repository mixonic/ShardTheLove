require File.join(File.dirname(__FILE__),'spec_helper')

describe Shard do

  it "should inherit from ActiveRecord::Base" do
    Shard.new.is_a?( ActiveRecord::Base ).should be_true
  end


end


require File.dirname(__FILE__) + '/../../shard_the_love'

namespace :db do

  namespace :directory do

    desc "Migrate the directory server."
    task :migrate => :environment do
      ActiveRecord::Base.establish_connection( ShardTheLove::ENV+'_directory' )
      ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migrator.migrate(ShardTheLove::DB_PATH+"migrate_directory/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
      Rake::Task["db:directory:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
    end

    namespace :schema do

      desc "Create a db/directory_schema.rb file that can be portably used against any DB supported by AR"
      task :dump => :environment do
        require 'active_record/schema_dumper'
        ActiveRecord::Base.establish_connection( ShardTheLove::ENV+'_directory' )
        File.open(ENV['SCHEMA'] || ShardTheLove::DB_PATH+"directory_schema.rb", "w") do |file|
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
        end
      end

    end

  end

  namespace :shards do

    desc "Migrate all shards."
    task :migrate => :environment do
      ActiveRecord::Base.configurations.each do |name,config|
        if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
          next if name.to_s == "#{ShardTheLove::ENV}_directory"
          ActiveRecord::Base.establish_connection( name )
          ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
          ActiveRecord::Migrator.migrate(ShardTheLove::DB_PATH+"migrate_shards/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
          Rake::Task["db:shards:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
        else
          next
        end
      end
    end
    
    namespace :schema do

      desc "Create a db/shards_schema.rb file that can be portably used against any DB supported by AR"
      task :dump => :environment do
        require 'active_record/schema_dumper'
        ActiveRecord::Base.configurations.each do |name,config|
          if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
            next if name.to_s == "#{ShardTheLove::ENV}_directory"
            File.open(ENV['SCHEMA'] || ShardTheLove::DB_PATH+"shards_schema.rb", "w") do |file|
              ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
            end
            break
          end
        end
      end

    end

  end

end

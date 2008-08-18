
namespace :db do

  namespace :directory do

    desc "Migrate the directory server."
    task :migrate => ShardTheLove::RAKE_ENV_SETUP do
      ActiveRecord::Base.establish_connection( ShardTheLove::ENV+'_directory' )
      ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migrator.migrate(ShardTheLove::DB_PATH+"migrate_directory/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
      Rake::Task["db:directory:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
    end

    desc "Empty the test database"
    task :purge_test => ShardTheLove::RAKE_ENV_SETUP do
      abcs = HashWithIndifferentAccess.new(ActiveRecord::Base.configurations)
      case abcs["test_directory"]["adapter"]
      when "mysql"
        ActiveRecord::Base.establish_connection('test_directory')
        ActiveRecord::Base.connection.recreate_database(abcs["test_directory"]["database"])
      when "postgresql"
        ActiveRecord::Base.clear_active_connections!
        drop_database(abcs['test_directory'])
        create_database(abcs['test_directory'])
      when "sqlite","sqlite3"
        dbfile = abcs["test_directory"]["database"] || abcs["test_directory"]["dbfile"]
        File.delete(dbfile) if File.exist?(dbfile)
      when "sqlserver"
        dropfkscript = "#{abcs["test_directory"]["host"]}.#{abcs["test_directory"]["database"]}.DP1".gsub(/\\/,'-')
        `osql -E -S #{abcs["test_directory"]["host"]} -d #{abcs["test_directory"]["database"]} -i #{ShardTheLove::DB_PATH}#{dropfkscript}`
        `osql -E -S #{abcs["test_directory"]["host"]} -d #{abcs["test_directory"]["database"]} -i #{ShardTheLove::DB_PATH}#{ShardTheLove::ENV}_directory_structure.sql`
      when "oci", "oracle"
        ActiveRecord::Base.establish_connection(:test_directory)
        ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      when "firebird"
        ActiveRecord::Base.establish_connection(:test_directory)
        ActiveRecord::Base.connection.recreate_database!
      else
        raise "Task not supported by '#{abcs["test_directory"]["adapter"]}'"
      end
    end

    namespace :schema do

      desc "Create a db/directory_schema.rb file that can be portably used against any DB supported by AR"
      task :dump => ShardTheLove::RAKE_ENV_SETUP do
        require 'active_record/schema_dumper'
        ActiveRecord::Base.establish_connection( ShardTheLove::ENV+'_directory' )
        File.open(ENV['SCHEMA'] || ShardTheLove::DB_PATH+"directory_schema.rb", "w") do |file|
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
        end
      end

      desc "Load a schema.rb file into the database"
      task :load => ShardTheLove::RAKE_ENV_SETUP do
        ActiveRecord::Base.establish_connection(ShardTheLove::ENV+'_directory')
        file = ENV['SCHEMA'] || ShardTheLove::DB_PATH+"directory_schema.rb"
        load(file)
      end

      desc "Recreate the test database from the current environment's database schema"
      task :clone => %w(db:directory:schema:dump db:directory:purge_test) do
        ActiveRecord::Base.establish_connection('test_directory')
        ActiveRecord::Schema.verbose = false
        load(ShardTheLove::DB_PATH+"directory_schema.rb")
      end

    end

  end

  namespace :shards do

    desc "Migrate all shards."
    task :migrate => ShardTheLove::RAKE_ENV_SETUP do
      ActiveRecord::Base.configurations.each do |name,config|
        if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
          next if name.to_s == "#{ShardTheLove::ENV}_directory"
          ActiveRecord::Base.establish_connection( config )
          ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
          ActiveRecord::Migrator.migrate(ShardTheLove::DB_PATH+"migrate_shards/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
          Rake::Task["db:shards:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
        else
          next
        end
      end
    end
    
    desc "Empty the test database"
    task :purge_test => ShardTheLove::RAKE_ENV_SETUP do
      ActiveRecord::Base.configurations.each do |name,config|
        config = HashWithIndifferentAccess.new(config)
        if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
          next if name.to_s == "#{ShardTheLove::ENV}_directory"
          case config["adapter"]
          when "mysql"
            ActiveRecord::Base.establish_connection(name.to_s)
            ActiveRecord::Base.connection.recreate_database(config["database"])
          when "postgresql"
            ActiveRecord::Base.clear_active_connections!
            drop_database(config)
            create_database(config)
          when "sqlite","sqlite3"
            dbfile = config["database"] || config["dbfile"]
            File.delete(dbfile) if File.exist?(dbfile)
          when "sqlserver"
            dropfkscript = "#{config["host"]}.#{config["database"]}.DP1".gsub(/\\/,'-')
            `osql -E -S #{config["host"]} -d #{config["database"]} -i #{ShardTheLove::DB_PATH}#{dropfkscript}`
            `osql -E -S #{config["host"]} -d #{config["database"]} -i #{ShardTheLove::DB_PATH}#{ShardTheLove::ENV}_shards_structure.sql`
          when "oci", "oracle"
            ActiveRecord::Base.establish_connection(name)
            ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
              ActiveRecord::Base.connection.execute(ddl)
            end
          when "firebird"
            ActiveRecord::Base.establish_connection(name)
            ActiveRecord::Base.connection.recreate_database!
          else
            raise "Task not supported by '#{config["adapter"]}'"
          end
        end
      end
    end
    
    namespace :schema do

      desc "Create a db/shards_schema.rb file that can be portably used against any DB supported by AR"
      task :dump => ShardTheLove::RAKE_ENV_SETUP do
        require 'active_record/schema_dumper'
        ActiveRecord::Base.configurations.each do |name,config|
          if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
            next if name.to_s == "#{ShardTheLove::ENV}_directory"
            ActiveRecord::Base.establish_connection( config )
            File.open(ENV['SCHEMA'] || ShardTheLove::DB_PATH+"shards_schema.rb", "w") do |file|
              ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
            end
            break
          end
        end
      end

      desc "Load a schema.rb file into the database"
      task :load => ShardTheLove::RAKE_ENV_SETUP do
        ActiveRecord::Base.configurations.each do |name,config|
          if name.to_s =~ /^#{ShardTheLove::ENV}_.*/
            next if name.to_s == "#{ShardTheLove::ENV}_directory"
            ActiveRecord::Base.establish_connection(config)
            file = ENV['SCHEMA'] || ShardTheLove::DB_PATH+"shards_schema.rb"
            load(file)
          end
        end
      end

      desc "Recreate the test database from the current environment's database schema"
      task :clone => %w(db:shards:schema:dump db:shards:purge_test) do
        ActiveRecord::Base.configurations.each do |name,config|
          if name.to_s =~ /^test_.*/
            next if name.to_s == "test_directory"
            ActiveRecord::Base.establish_connection(name.to_s)
            ActiveRecord::Schema.verbose = false
            load(ShardTheLove::DB_PATH+"shards_schema.rb")
          end
        end
      end
      
    end

  end

end

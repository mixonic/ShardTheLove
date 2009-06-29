module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements

      def assume_migrated_upto_version(version)
        version = version.to_i
        sm_table = quote_table_name(ActiveRecord::Migrator.schema_migrations_table_name)

        migrated = select_values("SELECT version FROM #{sm_table}").map(&:to_i)

        current_conn = ActiveRecord::Base.connection.instance_variable_get(:@current_connection_name).to_s

        shard_match = current_conn.match(/^#{ShardTheLove::ENV}_(.*)/)
        migrate_dir = 'migrate'
        if shard_match
          if current_conn == "#{ShardTheLove::ENV}_directory"
            migrate_dir = 'migrate_directory'
          else
            migrate_dir = 'migrate_shards'
          end
        end
        versions = Dir['db/'+migrate_dir+'/[0-9]*_*.rb'].map do |filename|
          filename.split('/').last.split('_').first.to_i
        end

        unless migrated.include?(version)
          execute "INSERT INTO #{sm_table} (version) VALUES ('#{version}')"
        end

        inserted = Set.new
        (versions - migrated).each do |v|
          if inserted.include?(v)
            raise "Duplicate migration #{v}. Please renumber your migrations to resolve the conflict."
          elsif v < version
            execute "INSERT INTO #{sm_table} (version) VALUES ('#{v}')"
            inserted << v
          end
        end
      end

    end
  end
end

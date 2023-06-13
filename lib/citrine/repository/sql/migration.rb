# frozen-string-literal: true
require "pathname"

module Citrine
	module Repository
    class Sql
      def default_migration_dir
        File.join("db", "migrations", options[:database])
      end

      def migration_dir
        @migration_dir ||= init_migration_dir
      end

      def default_migration_table; nil; end

      def migration_table
        @migration_table || init_migration_table
      end

      protected
      
      def init_migration_dir
        dir = Pathname.new(options[:migration_dir] || default_migration_dir)
        dir.absolute? ? dir : options[:work_dir].join(dir)
      end

      def init_migration_table
        (options[:migration_table] || default_migration_table)&.to_sym
      end

      def _run_migration!(action, **opts)
        load_migration_extension
        send("#{action}_migration", **opts)
      end

      def load_migration_extension
        require "sequel/core"
				Sequel.extension :migration
      end

      def migrate_migration(version: nil)
        run_migrator(target: version.nil? ? nil : Integer(version))
        info "Completed migration up of #{options[:database]}"
      end
      
      def rollback_migration(step: 1)
        step = Integer(step)
        down_migration(step)
        info "Completed migration down of #{options[:database]} for #{step} step(s)"
      end

      def redo_migration(step: 1)
        step = Integer(step)
        down_migration(step)
        up_migration(step)
        info "Completed migration redo of #{options[:database]} for #{step} step(s)"
      end

      def step_migration(step)
        run_migrator(relative: Integer(step))
      end
      alias_method :up_migration, :step_migration
      
      def down_migration(step)
        step_migration(- step)
      end

      def run_migrator(**opts)
        Sequel::Migrator.run(@database, migration_dir, 
                             table: migration_table, **opts)
      end
    end
	end
end
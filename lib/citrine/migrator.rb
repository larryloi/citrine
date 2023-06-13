# frozen-string-literal: true
module Citrine
  class Migrator < Actor
    MIGRATION_ACTIONS = %w(migrate rollback redo)

    def start_migration(command)
      repository, opts = parse_command(command)
      if validate_command_options(opts)
        migration_repositories(repository).collect do |repo|
          future.send(:run_migration, repo, **opts)
        end.each { |f| f.value }
      end
      quit
    rescue StandardError => e
      quit "Migration failed: #{e.class.name} - #{e.message}"
    end

    protected

    def parse_command(command)
      opts = { action: "migrate" }
      unless command.nil?
        repository, action, argument = command.split(":")
        opts[:action] = action || "migrate"
        case opts[:action]
        when "migrate"
          opts[:version] = argument unless argument.nil?
        when "rollback", "redo"
          opts[:step] = argument unless argument.nil?
        end
      end
      [repository, opts]
    end

    def validate_command_options(opts)
      if MIGRATION_ACTIONS.include?(opts[:action])
        true
      else
        quit "Migration action must be: #{MIGRATION_ACTIONS.join(', ')}"
        false
      end
    end

    def migration_repositories(repository)
      if repository.nil?
        repositories
      else
        repositories.select do |r|
          repository == r.to_s or 
          repository == actor(r).options[:database]
        end.tap do |repos|
          if repos.empty?
            quit "Error!! Migration repository #{repository} is NOT found"
          end
        end
      end
    end

    def repositories
      registered_actors.select do |name|
        actor(name).is_a?(Citrine::Repository::Base)
      end
    end

    def run_migration(repository, **opts)
      actor(repository).run_migration(**opts)
    end
  end
end
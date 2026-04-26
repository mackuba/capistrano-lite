# frozen_string_literal: true

require 'capistrano/recipes/deploy/strategy/base'

module Capistrano
  module Deploy
    module Strategy

      # Implements the deployment strategy that keeps a cached checkout of
      # the source code on the remote server. Each deploy simply updates the
      # cached checkout, and then does a copy from the cached copy to the
      # final deployment location.

      class RemoteCache < Base

        # Executes the SCM command for this strategy and writes the REVISION mark file on the server.
        def deploy!
          update_repository_cache
          copy_repository_cache
        end

        def check!
          super.check do |d|
            d.remote.command(source.command)
            d.remote.command("rsync") unless copy_exclude.empty?
            d.remote.writable(shared_path)
          end
        end


        private

        def repository_cache
          File.join(shared_path, configuration[:repository_cache] || "cached-copy")
        end

        def update_repository_cache
          logger.trace "updating the cached checkout on the server"

          command = "if [ -d #{repository_cache} ]; then " +
            "#{source.sync(revision, repository_cache)}; " +
            "else #{source.checkout(revision, repository_cache)}; fi"

          scm_run(command)
        end

        def copy_repository_cache
          logger.trace "copying the cached version to #{configuration[:release_path]}"

          if copy_exclude.empty?
            run "cp -RPp #{repository_cache} #{configuration[:release_path]} && #{mark}"
          else
            exclusions = copy_exclude.map { |e| %(--exclude="#{e}") }.join(' ')
            run "rsync -lrpt #{exclusions} #{repository_cache}/ #{configuration[:release_path]} && #{mark}"
          end
        end

        def copy_exclude
          @copy_exclude ||= Array(configuration.fetch(:copy_exclude, []))
        end

        # Runs the given command, filtering output back through the
        # #handle_data filter of the SCM implementation.
        def scm_run(command)
          run(command) do |ch, stream, text|
            ch[:state] ||= { :channel => ch }
            output = source.handle_data(ch[:state], stream, text)
            ch.send_data(output) if output
          end
        end

        # Returns the command which will write the identifier of the
        # revision being deployed to the REVISION file on the server.
        def mark
          "(echo #{revision} > #{configuration[:release_path]}/REVISION)"
        end
      end
    end
  end
end

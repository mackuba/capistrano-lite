# frozen_string_literal: true

require 'capistrano/errors'

module Capistrano
  class Configuration
    module Actions
      module Inspect

        # Streams the result of the command from the configured server.
        # The command is invoked via #invoke_command.
        #
        # Usage:
        #
        #   desc "Run a tail on multiple log files at the same time"
        #   task :tail_fcgi do
        #     stream "tail -f #{shared_path}/log/fastcgi.crash.log"
        #   end

        def stream(command, options = {})
          invoke_command(command, options.merge(:eof => !command.include?(sudo))) do |ch, stream, out|
            puts out if stream == :out
            warn "[err :: #{ch[:server]}] #{out}" if stream == :err
          end
        end

        # Executes the given command on the first server targetted by the
        # current task, collects it's stdout into a string, and returns the
        # string. The command is invoked via #invoke_command.

        def capture(command, options = {})
          output = "".dup

          invoke_command(command, options.merge(:once => true, :eof => !command.include?(sudo))) do |ch, stream, data|
            case stream
            when :out then output << data
            when :err then warn "[err :: #{ch[:server]}] #{data}"
            end
          end

          output
        end
      end
    end
  end
end

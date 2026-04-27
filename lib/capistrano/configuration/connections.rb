# frozen_string_literal: true

require 'capistrano/ssh'
require 'capistrano/errors'

module Capistrano
  class Configuration
    module Connections
      attr_accessor :session

      def initialize_connections #:nodoc:
        @session = nil
        @failed = false
      end

      # Used to force a connection to be made to the current task's server.
      # Connections are normally made lazily in Capistrano--you can use this
      # to force them open before performing some operation that might be
      # time-sensitive.

      def connect!
        establish_connection_to_server
      end

      # Ensures that there is an active session for the server.

      def establish_connection_to_server
        return if @session

        server = resolved_server
        @session = SSH.connect(server, self)
      rescue Exception => err
        raise err unless server

        error = ConnectionError.new("connection failed for: #{server} (#{err.class}: #{err.message})")
        error.host = server
        raise error
      end

      # Determines the configured server, establishes a connection to it, and
      # yields to the command and transfer layers.

      def execute_on_server
        raise ArgumentError, "expected a block" unless block_given?

        task = current_task
        return if task && task.continue_on_error? && @failed

        begin
          establish_connection_to_server
        rescue ConnectionError => error
          raise error unless task && task.continue_on_error?
          @failed = true
          return
        end

        begin
          yield
        rescue RemoteError => error
          raise error unless task && task.continue_on_error?
          @failed = true
        end
      end
    end
  end
end

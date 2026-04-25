require 'capistrano/ssh'
require 'capistrano/errors'

module Capistrano
  class Configuration
    module Connections
      def self.included(base) #:nodoc:
        base.send :alias_method, :initialize_without_connections, :initialize
        base.send :alias_method, :initialize, :initialize_with_connections
      end

      attr_accessor :session

      def initialize_with_connections(*args) #:nodoc:
        initialize_without_connections(*args)
        @session = nil
        @failed = false
      end

      # Indicate that the configured server could not be connected to.
      def failed!
        @failed = true
      end

      # Query whether previous connection attempts to the configured server
      # have failed.
      def failed?
        @failed
      end

      # Used to force a connection to be made to the current task's server.
      # Connections are normally made lazily in Capistrano--you can use this
      # to force them open before performing some operation that might be
      # time-sensitive.
      def connect!(options={})
        execute_on_server(options) { }
      end

      # Ensures that there is an active session for the server.
      def establish_connection_to(server)
        begin
          self.session ||= SSH.connect(server, self)
        rescue Exception => err
          error = ConnectionError.new("connection failed for: #{server} (#{err.class}: #{err.message})")
          error.hosts = [server]
          raise error
        end
      end

      # Destroys the session for the server.
      def teardown_connection_to(server)
        begin
          if session
            session.close
            self.session = nil
          end
        rescue IOError, Net::SSH::Disconnect
          # the TCP connection is already dead
        end
      end

      # Determines the configured server, establishes a connection to it, and
      # yields the server to the command and transfer layers.
      def execute_on_server(options={})
        raise ArgumentError, "expected a block" unless block_given?

        task = current_task
        server = active_server
        return if task && task.continue_on_error? && failed?

        logger.trace "server: #{server.host.inspect}"

        begin
          establish_connection_to(server)
        rescue ConnectionError => error
          raise error unless task && task.continue_on_error?
          failed!
          return
        end

        begin
          yield server
        rescue RemoteError => error
          raise error unless task && task.continue_on_error?
          failed!
        end
      end
    end
  end
end

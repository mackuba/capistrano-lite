require 'capistrano/ssh'
require 'capistrano/errors'

module Capistrano
  class Configuration
    module Connections
      def self.included(base) #:nodoc:
        base.send :alias_method, :initialize_without_connections, :initialize
        base.send :alias_method, :initialize, :initialize_with_connections
      end

      class DefaultConnectionFactory #:nodoc:
        def initialize(options)
          @options = options
        end

        def connect_to(server)
          SSH.connect(server, @options)
        end
      end

      # A hash of the SSH sessions that are currently open and available.
      # Because sessions are constructed lazily, this will only contain
      # connections to the server once it has been the target of one or more
      # executed tasks. Stored on a per-thread basis to improve thread-safety.
      def sessions
        Thread.current[:sessions] ||= {}
      end

      def initialize_with_connections(*args) #:nodoc:
        initialize_without_connections(*args)
        Thread.current[:sessions] = {}
        Thread.current[:failed_sessions] = []
      end

      # Indicate that the given server could not be connected to.
      def failed!(server)
        Thread.current[:failed_sessions] << server
      end

      # Query whether previous connection attempts to the given server have
      # failed.
      def has_failed?(server)
        Thread.current[:failed_sessions].include?(server)
      end

      # Used to force a connection to be made to the current task's server.
      # Connections are normally made lazily in Capistrano--you can use this
      # to force them open before performing some operation that might be
      # time-sensitive.
      def connect!(options={})
        execute_on_servers(options) { }
      end

      # Returns the object responsible for establishing new SSH connections.
      # The factory will respond to #connect_to, which can be used to
      # establish a connection to a server defined via a ServerDefinition object.
      def connection_factory
        @connection_factory ||= DefaultConnectionFactory.new(self)
      end

      # Ensures that there is an active session for the server.
      def establish_connections_to(server)
        raise ArgumentError, "only one server may be connected" if server.is_a?(Array)

        begin
          sessions[server] ||= connection_factory.connect_to(server)
        rescue Exception => err
          error = ConnectionError.new("connection failed for: #{server} (#{err.class}: #{err.message})")
          error.hosts = [server]
          raise error
        end
      end

      # Destroys the session for the server.
      def teardown_connections_to(server)
        begin
          session = sessions.delete(server)
          session.close if session
        rescue IOError, Net::SSH::Disconnect
          # the TCP connection is already dead
        end
      end

      # Determines the server within the current task's scope.
      def filter_servers(options={})
        if task = current_task
          servers = find_servers_for_task(task, options)

          if task.continue_on_error?
            servers.delete_if { |s| has_failed?(s) }
          end
        else
          servers = find_servers(options)
        end

        return [task, []] if servers.empty? && task && task.continue_on_error?
        raise Capistrano::NoMatchingServersError, "no server configured" if servers.empty? && !dry_run
        [task, servers.compact]
      end

      # Determines the server within the current task's scope, establishes a
      # connection to it, and then yields it as a one-item list for the command
      # and transfer layers.
      def execute_on_servers(options={})
        raise ArgumentError, "expected a block" unless block_given?

        task, servers = filter_servers(options)
        return if servers.empty?
        server = servers.first
        logger.trace "server: #{server.host.inspect}"

        begin
          establish_connections_to(server)
        rescue ConnectionError => error
          raise error unless task && task.continue_on_error?
          failed!(server)
          return
        end

        begin
          yield [server]
        rescue RemoteError => error
          raise error unless task && task.continue_on_error?
          error.hosts.each { |h| failed!(h) }
        end
      end
    end
  end
end

require 'enumerator'
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
      # connections to those servers that have been the targets of one or more
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

      # Used to force connections to be made to the current task's servers.
      # Connections are normally made lazily in Capistrano--you can use this
      # to force them open before performing some operation that might be
      # time-sensitive.
      def connect!(options={})
        execute_on_servers(options) { }
      end

      # Returns the object responsible for establishing new SSH connections.
      # The factory will respond to #connect_to, which can be used to
      # establish connections to servers defined via ServerDefinition objects.
      def connection_factory
        @connection_factory ||= DefaultConnectionFactory.new(self)
      end

      # Ensures that there are active sessions for each server in the list.
      def establish_connections_to(servers)
        failed_servers = []

        Array(servers).each { |server| safely_establish_connection_to(server, Thread.current, failed_servers) }

        if failed_servers.any?
          errors = failed_servers.map { |h| "#{h[:server]} (#{h[:error].class}: #{h[:error].message})" }
          error = ConnectionError.new("connection failed for: #{errors.join(', ')}")
          error.hosts = failed_servers.map { |h| h[:server] }
          raise error
        end
      end

      # Destroys sessions for each server in the list.
      def teardown_connections_to(servers)
        servers.each do |server|
          begin
            session = sessions.delete(server)
            session.close if session
          rescue IOError, Net::SSH::Disconnect
            # the TCP connection is already dead
          end
        end
      end

      # Determines the set of servers within the current task's scope
      def filter_servers(options={})
        if task = current_task
          servers = find_servers_for_task(task, options)

          if servers.empty?
            raise Capistrano::NoMatchingServersError, "`#{task.fully_qualified_name}' requires a configured server" unless dry_run
            return [task, []]
          end

          if task.continue_on_error?
            servers.delete_if { |s| has_failed?(s) }
          end
        else
          servers = find_servers(options)
          if servers.empty? && !dry_run
            raise Capistrano::NoMatchingServersError, "no server configured"
          end
        end

        [task, servers.compact]
      end

      # Determines the set of servers within the current task's scope and
      # establishes connections to them, and then yields that list of
      # servers.
      def execute_on_servers(options={})
        raise ArgumentError, "expected a block" unless block_given?

        task, servers = filter_servers(options)
        return if servers.empty?
        logger.trace "servers: #{servers.map { |s| s.host }.inspect}"

        begin
          establish_connections_to(servers)
        rescue ConnectionError => error
          raise error unless task && task.continue_on_error?
          error.hosts.each do |h|
            servers.delete(h)
            failed!(h)
          end
        end

        begin
          yield servers
        rescue RemoteError => error
          raise error unless task && task.continue_on_error?
          error.hosts.each { |h| failed!(h) }
        end
      end

      private

        def safely_establish_connection_to(server, thread, failures=nil)
          thread[:sessions] ||= {}
          thread[:sessions][server] ||= connection_factory.connect_to(server)
        rescue Exception => err
          raise unless failures
          failures << { :server => server, :error => err }
        end
    end
  end
end

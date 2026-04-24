require 'capistrano/server_definition'
require 'capistrano/errors'

module Capistrano
  class Configuration
    module Servers
      def self.included(base) #:nodoc:
        base.send :alias_method, :initialize_without_servers, :initialize
        base.send :alias_method, :initialize, :initialize_with_servers
      end

      def initialize_with_servers(*args) #:nodoc:
        initialize_without_servers(*args)
        @server = nil
      end

      # Define the server. The host may include user and port information, or
      # those may be supplied as options:
      #
      #   server "www@example.com"
      #   server "app.example.com", :user => "deploy"
      def server(host, options = {})
        raise ArgumentError, "server accepts one host and an optional options hash" unless options.is_a?(Hash)
        raise ArgumentError, "you may only define one server" if @server

        @server = server_definition_from(host, options)
      end

      # Identifies the configured server that the given task should be executed on.
      def find_servers_for_task(task, options={})
        find_servers
      end

      # Returns the single configured server. If the HOST environment variable
      # is set, it replaces the configured host name while preserving configured
      # connection options such as user, port, password, and SSH options.
      def find_servers(options={})
        [active_server]
      end

    protected

      def active_server
        raise Capistrano::NoMatchingServersError, "no server configured" unless @server

        host = ENV['HOST']
        raise ArgumentError, "HOST must name a single host" if host && host.strip.empty?

        host ? server_definition_from(host, connection_options_for(@server)) : @server
      end

      def server_definition_from(host, options={})
        case host
        when ServerDefinition
          host
        when String
          host = host.strip
          raise ArgumentError, "server must name a single host" if host.empty? || host.include?(',')
          ServerDefinition.new(host, options)
        else
          raise ArgumentError, "servers must be defined as host strings or ServerDefinition instances"
        end
      end

      def connection_options_for(server)
        options = server.options.dup
        options[:user] = server.user if server.user
        options[:port] = server.port if server.port
        options
      end
    end
  end
end

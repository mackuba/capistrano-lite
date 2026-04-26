# frozen_string_literal: true

require 'capistrano/server_definition'
require 'capistrano/errors'

module Capistrano
  class Configuration
    module Servers
      def initialize_servers #:nodoc:
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

      # Returns the configured server. If the SERVER environment variable
      # is set, it replaces the configured host name while preserving configured
      # connection options such as user, port, and SSH options.

      def resolved_server
        if env_key = server_override_env
          host = ENV[env_key].strip
          raise ArgumentError, "#{env_key} must name a single server" if host.empty? || host.include?(',')

          options = @server ? connection_options_for(@server) : {}
          server_definition_from(host, options)
        else
          @server or raise Capistrano::NoMatchingServersError, "no server configured"
        end
      end


      protected

      def server_override_env
        if ENV.key?('SERVER')
          'SERVER'
        elsif ENV.key?('HOSTS')
          'HOSTS'
        end
      end

      def server_definition_from(host, options = {})
        raise ArgumentError, "server must be defined as a string" unless host.is_a?(String)

        host = host.strip
        raise ArgumentError, "server value must be a single hostname" if host.empty? || host.include?(',')

        ServerDefinition.new(host, options)
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

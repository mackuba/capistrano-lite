require 'capistrano/server_definition'

module Capistrano
  class Configuration
    module Roles
      def self.included(base) #:nodoc:
        base.send :alias_method, :initialize_without_roles, :initialize
        base.send :alias_method, :initialize, :initialize_with_roles
      end

      # The single server defined for this configuration.
      attr_reader :server

      def initialize_with_roles(*args) #:nodoc:
        initialize_without_roles(*args)
        @server = nil
      end

      # Define the single server to be used for all tasks. Any previous value
      # will be replaced.
      #
      # Usage:
      #
      #   server "deploy@example.com"
      #   server "deploy@example.com", :port => 2222
      #
      # The legacy +role+ API is supported for compatibility and delegates to
      # this method.
      def server(host=nil, *args, &block)
        return @server if host.nil? && !block_given?

        options = args.last.is_a?(Hash) ? args.pop : {}
        host ||= (block.call if block_given?)
        raise ArgumentError, "you must provide a host for the server" unless host

        @server = host.is_a?(ServerDefinition) ? host : ServerDefinition.new(host, options)
      end

      def resolved_server
        return server if server
        return unless exists?(:server)
        ServerDefinition.new(fetch(:server))
      end
    end
  end
end

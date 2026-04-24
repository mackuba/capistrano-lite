require 'capistrano/server_definition'

module Capistrano
  class Configuration
    module Servers
      def self.included(base) #:nodoc:
        base.send :alias_method, :initialize_without_servers, :initialize
        base.send :alias_method, :initialize, :initialize_with_servers
      end

      # The current list of server definitions.
      attr_reader :servers

      def initialize_with_servers(*args) #:nodoc:
        initialize_without_servers(*args)
        @servers = []
      end

      # Define one or more servers. Hosts may include user and port information,
      # or those may be supplied as options:
      #
      #   server "www@example.com"
      #   server "app1.example.com", "app2.example.com", :user => "deploy"
      #   server "db.example.com", :primary => true
      def server(*hosts)
        options = hosts.last.is_a?(Hash) ? hosts.pop : {}
        raise ArgumentError, "you must specify at least one server" if hosts.empty?

        hosts.each { |host| @servers << server_definition_from(host, options) }
      end

      # Identifies all servers that the given task should be executed on.
      # The options hash accepts the same arguments as #find_servers, and any
      # preexisting options there will take precedence over the options in
      # the task.
      def find_servers_for_task(task, options={})
        find_servers(task.options.merge(options))
      end

      # Attempts to find all defined servers that match the given criteria.
      # The options hash may include a :hosts option (which should specify
      # an array of host names or ServerDefinition instances), an :only option
      # (specifying a hash of key/value pairs that any matching server must
      # match), an :except option (like :only, but the inverse), and a
      # :skip_hostfilter option to ignore the HOSTFILTER environment variable.
      #
      # Additionally, if the HOSTS environment variable is set, it will take
      # precedence over any other options.
      #
      # Yet additionally, if the HOSTFILTER environment variable is set, it
      # will limit the result to hosts found in that (comma-separated) list.
      #
      # Usage:
      #
      #   # return all known servers
      #   servers = find_servers
      #
      #   # find all servers that are not exempted from deployment
      #   servers = find_servers :except => { :no_release => true }
      #
      #   # returns the given hosts, translated to ServerDefinition objects
      #   servers = find_servers :hosts => "jamis@example.host.com"
      def find_servers(options={})
        return [] if options.key?(:hosts) && (options[:hosts].nil? || [] == options[:hosts])

        hosts  = server_list_from(ENV['HOSTS'] || options[:hosts])
        hosts = servers if hosts.empty?

        only   = options[:only] || {}
        except = options[:except] || {}

        hosts = hosts.select { |server| only.all? { |key,value| server.options[key] == value } }
        hosts = hosts.reject { |server| except.any? { |key,value| server.options[key] == value } }
        hosts = hosts.uniq

        options[:skip_hostfilter] ? hosts : filter_server_list(hosts)
      end

    protected

      def filter_server_list(servers)
        return servers unless ENV['HOSTFILTER']

        filters = ENV['HOSTFILTER'].split(/,/)
        servers.select { |server| filters.include?(server.host) }
      end

      def server_list_from(hosts)
        hosts = hosts.split(/,/) if String === hosts
        hosts = Array(hosts).flatten
        hosts.map { |s| server_definition_from(s) }
      end

      def server_definition_from(host, options={})
        case host
        when ServerDefinition
          host
        when String
          ServerDefinition.new(host.strip, options)
        else
          raise ArgumentError, "servers must be defined as host strings or ServerDefinition instances"
        end
      end
    end
  end
end

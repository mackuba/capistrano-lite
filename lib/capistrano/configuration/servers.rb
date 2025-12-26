module Capistrano
  class Configuration
    module Servers
      # Identifies all servers that the given task should be executed on.
      def find_servers_for_task(_task, options={})
        find_servers(options)
      end

      # Attempts to find the configured server. Options are ignored, since only
      # a single server is supported.
      def find_servers(options={})
        host = options[:hosts] || resolved_server
        host = host.first if host.is_a?(Array)
        return nil unless host
        host = ServerDefinition.new(host) if String === host
        host
      end
    end
  end
end

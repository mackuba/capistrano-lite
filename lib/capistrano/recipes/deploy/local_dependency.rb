module Capistrano
  module Deploy
    class LocalDependency
      attr_reader :configuration
      attr_reader :message

      def initialize(configuration)
        @configuration = configuration
        @success = true
      end

      def command(command)
        @message ||= "`#{command}' could not be found in the path on the local host"
        @success = find_in_path(command)
        self
      end

      def or(message)
        @message = message
        self
      end

      def pass?
        @success
      end

      private

      # Searches the path, looking for the given utility. If an executable
      # file is found that matches the parameter, this returns true.
      def find_in_path(utility)
        path = (ENV['PATH'] || "").split(File::PATH_SEPARATOR)

        path.each do |dir|
          file = File.join(dir, utility)
          return true if File.executable?(file)
        end

        false
      end
    end
  end
end

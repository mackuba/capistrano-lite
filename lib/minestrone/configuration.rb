require 'minestrone/logger'

require 'minestrone/configuration/alias_task'
require 'minestrone/configuration/callbacks'
require 'minestrone/configuration/connections'
require 'minestrone/configuration/execution'
require 'minestrone/configuration/loading'
require 'minestrone/configuration/log_formatters'
require 'minestrone/configuration/namespaces'
require 'minestrone/configuration/servers'
require 'minestrone/configuration/variables'

require 'minestrone/configuration/actions/file_transfer'
require 'minestrone/configuration/actions/inspect'
require 'minestrone/configuration/actions/invocation'

module Minestrone

  #
  # Represents a specific Minestrone configuration. A Configuration instance
  # may be used to load multiple recipe files, define and describe tasks,
  # define a server, and set configuration variables.
  #

  class Configuration

    # The logger instance defined for this configuration.
    attr_accessor :debug, :logger, :dry_run

    def initialize(options = {}) #:nodoc:
      @debug = false
      @dry_run = false
      @logger = Logger.new(options)

      initialize_connections
      initialize_execution
      initialize_loading
      initialize_namespaces
      initialize_servers
      initialize_variables
      initialize_invocation
      initialize_callbacks
    end

    # make the DSL easier to read when using lazy evaluation via lambdas
    alias defer lambda

    # The includes must come at the bottom, since they may redefine methods
    # defined in the base class.
    include AliasTask, Connections, Execution, Loading, LogFormatters, Namespaces, Servers, Variables

    # Mix in the actions
    include Actions::FileTransfer, Actions::Inspect, Actions::Invocation

    # Must mix last, because it hooks into previously defined methods
    include Callbacks

    (self.instance_methods & Kernel.methods).select do |name|
      # Select the instance methods owned by the Configuration class.
      self.instance_method(name).owner.to_s.start_with?("Minestrone::Configuration")
    end.select do |name|
      # Of those, select methods that are being shadowed by the Kernel module in the Namespace class.
      Namespaces::Namespace.method_defined?(name) && Namespaces::Namespace.instance_method(name).owner == Kernel
    end.each do |name|
      # Undefine the shadowed methods, since we want Namespace objects to defer handling to the Configuration object.
      Namespaces::Namespace.send(:undef_method, name)
    end
  end
end

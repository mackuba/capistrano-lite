# frozen_string_literal: true

require 'capistrano'
require 'capistrano/cli/help'
require 'capistrano/cli/options'
require 'capistrano/configuration'
require 'highline'

# work around problem where HighLine detects an eof on $stdin and raises an
# error.
HighLine.track_eof = false

module Capistrano

  # The CLI class encapsulates the behavior of capistrano when it is invoked
  # as a command-line utility. This allows other programs to embed Capistrano
  # and preserve its command-line semantics.

  class CLI

    # The array of (unparsed) command-line options
    attr_reader :args

    # Return a new CLI instance with the given arguments pre-parsed and
    # ready for execution.
    def self.parse(args)
      self.new(args).tap { |c| c.parse_options! }
    end

    # Invoke capistrano using the ARGV array as the option parameters. This
    # is what the command-line capistrano utility does.
    def self.execute
      parse(ARGV).execute!
    end

    # Return the object that provides UI-specific methods, such as prompts
    # and more.
    def self.ui
      @ui ||= HighLine.new
    end

    # Prompt for a password using echo suppression.
    def self.password_prompt(prompt = "Password: ")
      ui.ask(prompt) { |q| q.echo = false }
    end

    # Debug mode prompt
    def self.debug_prompt(cmd)
      ui.say("Preparing to execute command: #{cmd}")
      prompt = "Execute ([Yes], No, Abort) "
      ui.ask("#{prompt}?  ") do |q|
        q.overwrite = false
        q.default = 'y'
        q.validate = /(y(es)?)|(no?)|(a(bort)?|\n)/i
        q.responses[:not_valid] = prompt
      end
    end

    # Create a new CLI instance using the given array of command-line parameters
    # to initialize it. By default, +ARGV+ is used, but you can specify a
    # different set of parameters (such as when embedded cap in a program):
    #
    #   require 'capistrano/cli'
    #   Capistrano::CLI.parse(%W(-vvvv -f config/deploy update_code)).execute!
    #
    # Note that you can also embed cap directly by creating a new Configuration
    # instance and setting it up, The above snippet, redone using the
    # Configuration class directly, would look like:
    #
    #   require 'capistrano'
    #   require 'capistrano/cli'
    #   config = Capistrano::Configuration.new
    #   config.logger.level = Capistrano::Logger::TRACE
    #   config.set(:password) { Capistrano::CLI.password_prompt } # sudo password
    #   config.load "config/deploy"
    #   config.update_code
    #
    # There may be times that you want/need the additional control offered by
    # manipulating the Configuration directly, but generally interfacing with
    # the CLI class is recommended.

    def initialize(args)
      @args = args.dup
      $stdout.sync = true # so that Net::SSH prompts show up
    end

    # Using the options build when the command-line was parsed, instantiate
    # a new Capistrano configuration, initialize it, and execute the
    # requested actions.
    #
    # Returns the Configuration instance used, if successful.

    def execute!
      config = instantiate_configuration(options)

      config.debug = options[:debug]
      config.dry_run = options[:dry_run]
      config.logger.level = options[:verbose]

      set_pre_vars(config)
      load_recipes(config)

      config.trigger(:load)
      execute_requested_actions(config)
      config.trigger(:exit)

      config
    rescue Exception => error
      handle_error(error)
    end

    def execute_requested_actions(config)
      Array(options[:vars]).each { |name, value| config.set(name, value) }

      Array(options[:actions]).each do |action|
        config.find_and_execute_task(action, :before => :start, :after => :finish)
      end
    end

    def set_pre_vars(config) #:nodoc:
      config.set :password, options[:password]
      Array(options[:pre_vars]).each { |name, value| config.set(name, value) }
    end

    def load_recipes(config) #:nodoc:
      # load the standard recipe definition
      config.load 'standard'

      # load systemwide config/recipe definition
      config.load(options[:sysconf]) if options[:sysconf] && File.file?(options[:sysconf])

      # load user config/recipe definition
      config.load(options[:dotfile]) if options[:dotfile] && File.file?(options[:dotfile])

      Array(options[:recipes]).each { |recipe| config.load(recipe) }
    end

    # Primarily useful for testing, but subclasses of CLI could conceivably
    # override this method to return a Configuration subclass or replacement.

    def instantiate_configuration(options = {})
      Capistrano::Configuration.new(options)
    end

    def handle_error(error) #:nodoc:
      case error
      when Net::SSH::AuthenticationFailed
        abort "authentication failed for `#{error.message}'"
      when Capistrano::Error
        abort(error.message)
      else
        raise error
      end
    end

    include Options
    include Help # needs to be included last, because it overrides some methods
  end
end

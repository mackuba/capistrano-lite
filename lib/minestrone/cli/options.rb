# frozen_string_literal: true

require 'optparse'

module Minestrone
  class CLI
    module Options

      # The hash of (parsed) command-line options
      attr_reader :options

      # Return an OptionParser instance that defines the acceptable command
      # line switches for Minestrone, and what their corresponding behaviors
      # are.
      def option_parser #:nodoc:
        @logger = Logger.new
        @option_parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: #{File.basename($0)} [options] action ..."

          opts.on("-d", "--debug",
            "Prompts before each remote command execution."
          ) { |value| options[:debug] = true }

          opts.on("-e", "--explain TASK",
            "Displays help (if available) for the task."
          ) { |value| options[:explain] = value }

          opts.on("-F", "--default-config",
            "Always use default config, even with -f."
          ) { options[:default_config] = true }

          opts.on("-f", "--file FILE",
            "A recipe file to load. May be given more than once."
          ) { |value| options[:recipes] << value }

          opts.on("-H", "--long-help", "Explain these options and environment variables.") do
            long_help
            exit
          end

          opts.on("-h", "--help", "Display this help message.") do
            puts opts
            exit
          end

          opts.on("-l", "--logger [STDERR|STDOUT|file]",
            "Choose logger method. STDERR used by default."
          ) do |value|
            options[:output] = if value.nil? || value.upcase == 'STDERR'
                                 # Using default logger.
                                 nil
                               elsif value.upcase == 'STDOUT'
                                 $stdout
                               else
                                 value
                               end
          end

          opts.on("-n", "--dry-run",
            "Prints out commands without running them."
          ) { |value| options[:dry_run] = true }

          opts.on("-p", "--password",
            "Immediately prompt for the sudo password."
          ) { options[:password] = nil }

          opts.on("-q", "--quiet",
            "Make the output as quiet as possible."
          ) { options[:verbose] = 0 }

          opts.on("-S", "--set-before NAME=VALUE",
            "Set a variable before the recipes are loaded."
          ) do |pair|
            name, value = pair.split(/=/, 2)
            options[:pre_vars][name.to_sym] = value
          end

          opts.on("-s", "--set NAME=VALUE",
            "Set a variable after the recipes are loaded."
          ) do |pair|
            name, value = pair.split(/=/, 2)
            options[:vars][name.to_sym] = value
          end

          opts.on("-T", "--tasks [PATTERN]",
            "List all tasks (matching optional PATTERN) in the loaded recipe files."
          ) do |value|
            options[:tasks] = if value
              value
            else
              true
            end
            options[:verbose] ||= 0
          end

          opts.on("-t", "--tool",
            "Abbreviates the output of -T for tool integration."
          ) { options[:tool] = true }

          opts.on("-V", "--version",
            "Display the Minestrone version, and exit."
          ) do
            require 'minestrone/version'
            puts "Minestrone v#{Minestrone::Version}"
            exit
          end

          opts.on("-v", "--verbose",
            "Be more verbose. May be given more than once."
          ) do
            options[:verbose] ||= 0
            options[:verbose] += 1
          end

          opts.on("-X", "--skip-system-config",
            "Don't load the system config file (minestrone.conf)"
          ) { options.delete(:sysconf) }

          opts.on("-x", "--skip-user-config",
            "Don't load the user config file (.caprc)"
          ) { options.delete(:dotfile) }
        end
      end

      # If the arguments to the command are empty, this will print the
      # allowed options and exit. Otherwise, it will parse the command
      # line and set up any default options.

      def parse_options!
        @options = {
          :recipes => [],
          :actions => [],
          :vars => {},
          :pre_vars => {},
          :sysconf => default_sysconf,
          :dotfile => default_dotfile
        }

        if args.empty?
          warn "Please specify at least one action to execute."
          warn option_parser
          exit
        end

        option_parser.parse!(args)

        coerce_variable_types!

        # if no verbosity has been specified, be verbose
        options[:verbose] = 3 if !options.has_key?(:verbose)

        look_for_default_recipe_file! if options[:default_config] || options[:recipes].empty?
        extract_environment_variables!

        options[:actions].concat(args)

        password = options.has_key?(:password)
        options[:password] = Proc.new { self.class.password_prompt }
        options[:password] = options[:password].call if password
      end

      # Extracts name=value pairs from the remaining command-line arguments
      # and assigns them as environment variables.

      def extract_environment_variables!
        args.delete_if do |arg|
          next unless arg.match(/^(\w+)=(.*)$/)
          ENV[$1] = $2
        end
      end

      # Looks for a default recipe file in the current directory.

      def look_for_default_recipe_file!
        current = Dir.pwd

        loop do
          %w(Capfile capfile).each do |file|
            if File.file?(file)
              options[:recipes] << file
              @logger.info "Using recipes from #{File.join(current,file)}"
              return
            end
          end

          pwd = Dir.pwd
          Dir.chdir("..")
          break if pwd == Dir.pwd # if changing the directory made no difference, then we're at the top
        end

        Dir.chdir(current)
      end

      def default_sysconf #:nodoc:
        File.join(sysconf_directory, "minestrone.conf")
      end

      def default_dotfile #:nodoc:
        File.join(home_directory, ".caprc")
      end

      def sysconf_directory #:nodoc:
        '/etc'
      end

      def home_directory #:nodoc:
        ENV["HOME"] || "/"
      end

      def coerce_variable_types!
        [:pre_vars, :vars].each do |collection|
          options[collection].keys.each do |key|
            options[collection][key] = coerce_variable(options[collection][key])
          end
        end
      end

      def coerce_variable(value)
        case value
        when /^"(.*)"$/ then $1
        when /^'(.*)'$/ then $1
        when /^\d+$/ then value.to_i
        when /^\d+\.\d*$/ then value.to_f
        when "true" then true
        when "false" then false
        when "nil" then nil
        else value
        end
      end
    end
  end
end

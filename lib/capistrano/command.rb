require 'benchmark'
require 'capistrano/errors'
require 'capistrano/processable'

module Capistrano

  # This class encapsulates a single command to be executed on a set of remote
  # machines, one host at a time.
  class Command
    include Processable

    attr_reader :command, :options, :callback

    def self.process(command, sessions, options = {}, &block)
      new(command, sessions, options, &block).process!
    end

    # Instantiates a new command object. The +command+ must be a string
    # containing the command to execute. +sessions+ is an array of Net::SSH
    # session instances, and +options+ must be a hash containing any of the
    # following keys:
    #
    # * +logger+: (optional), a Capistrano::Logger instance
    # * +data+: (optional), a string to be sent to the command via it's stdin
    # * +env+: (optional), a string or hash to be interpreted as environment
    #   variables that should be defined for this command invocation.
    def initialize(command, sessions, options = {}, &block)
      @command = command.strip.gsub(/\r?\n/, "\\\n")
      @sessions = sessions
      @options = options
      @callback = block || Capistrano::Configuration.default_io_proc
      @channels = []
    end

    # Processes the command sequentially on all specified hosts. If the command
    # fails (non-zero return code) on any of the hosts, this will raise a
    # Capistrano::CommandError.
    def process!
      elapsed = Benchmark.realtime do
        sessions.each do |session|
          channel = open_channel(session)
          begin
            @active_sessions = [session]
            loop do
              break unless process_iteration { !channel[:closed] }
            end
          ensure
            @active_sessions = nil
          end
        end
      end

      logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger

      if (failed = @channels.select { |ch| ch[:status] != 0 }).any?
        commands = failed.inject({}) { |map, ch| (map[ch[:command]] ||= []) << ch[:server]; map }
        message = commands.map { |command, list| "#{command.inspect} on #{list.join(',')}" }.join("; ")
        error = CommandError.new("failed: #{message}")
        error.hosts = commands.values.flatten
        raise error
      end

      self
    end

    # Force the command to stop processing, by closing all open channels
    # associated with this command.
    def stop!
      @channels.each do |ch|
        ch.close unless ch[:closed]
      end
    end

    def sessions
      @active_sessions || @sessions
    end

    private

      def logger
        options[:logger]
      end

      def open_channel(session)
        server = session.xserver
        opened = nil

            returned = session.open_channel do |channel|
              opened = channel
              channel[:server] = server
              channel[:host] = server.host
              channel[:options] = options
              channel[:callback] = callback

              request_pty_if_necessary(channel) do |ch, success|
                if success
                  logger.trace "executing command", ch[:server] if logger
                  cmd = replace_placeholders(command, ch)

                  if options[:shell] == false
                    shell = nil
                  else
                    shell = "#{options[:shell] || "sh"} -c"
                    cmd = cmd.gsub(/'/) { |m| "'\\''" }
                    cmd = "'#{cmd}'"
                  end

                  command_line = [environment, shell, cmd].compact.join(" ")
                  ch[:command] = command_line

                  ch.exec(command_line)
                  ch.send_data(options[:data]) if options[:data]
                  ch.eof! if options[:eof]
                else
                  # just log it, don't actually raise an exception, since the
                  # process method will see that the status is not zero and will
                  # raise an exception then.
                  logger.important "could not open channel", ch[:server] if logger
                  ch.close
                end
              end

              channel.on_data do |ch, data|
                ch[:callback][ch, :out, data]
              end

              channel.on_extended_data do |ch, type, data|
                ch[:callback][ch, :err, data]
              end

              channel.on_request("exit-status") do |ch, data|
                ch[:status] = data.read_long
              end

              channel.on_request("exit-signal") do |ch, data|
                if logger
                  exit_signal = data.read_string
                  logger.important "command received signal #{exit_signal}", ch[:server]
                end
              end

              channel.on_close do |ch|
                ch[:closed] = true
              end
            end

        (returned || opened).tap { |channel| @channels << channel }
      end

      def request_pty_if_necessary(channel)
        if options[:pty]
          channel.request_pty do |ch, success|
            yield ch, success
          end
        else
          yield channel, true
        end
      end

      def replace_placeholders(command, channel)
        command.gsub(/\$CAPISTRANO:HOST\$/, channel[:host])
      end

      # prepare a space-separated sequence of variables assignments
      # intended to be prepended to a command, so the shell sets
      # the environment before running the command.
      # i.e.: options[:env] = {'PATH' => '/opt/ruby/bin:$PATH',
      #                        'TEST' => '( "quoted" )'}
      # environment returns:
      # "env TEST=(\ \"quoted\"\ ) PATH=/opt/ruby/bin:$PATH"
      def environment
        return if options[:env].nil? || options[:env].empty?
        @environment ||= if String === options[:env]
            "env #{options[:env]}"
          else
            options[:env].inject("env") do |string, (name, value)|
              value = value.to_s.gsub(/[ "]/) { |m| "\\#{m}" }
              string << " #{name}=#{value}"
            end
          end
      end
  end
end

require "utils"
require "capistrano/configuration/actions/invocation"
require "capistrano/configuration/actions/file_transfer"

class ConfigurationActionsInvocationTest < Test::Unit::TestCase
  class MockConfig
    attr_reader :options
    attr_accessor :debug
    attr_accessor :dry_run
    attr_accessor :servers

    def initialize
      @options = {}
      @servers = []
      @options[:default_environment] = {}
      @options[:default_run_options] = {}
    end

    def [](*args)
      @options[*args]
    end

    def set(name, value)
      @options[name] = value
    end

    def fetch(*args)
      @options.fetch(*args)
    end

    def filter_servers(options = {})
      [nil, @servers]
    end

    def execute_on_servers(options = {})
      yield @servers
    end

    include Capistrano::Configuration::Actions::Invocation
    include Capistrano::Configuration::Actions::FileTransfer
  end

  def setup
    @config = MockConfig.new
    @original_io_proc = MockConfig.default_io_proc
  end

  def teardown
    MockConfig.default_io_proc = @original_io_proc
  end

  def test_run_options_should_be_passed_to_execute_on_servers
    @config.expects(:execute_on_servers).with(:foo => "bar", :eof => true)
    @config.run "ls", :foo => "bar"
  end

  def test_run_will_return_if_dry_run
    @config.expects(:dry_run).returns(true)
    @config.expects(:execute_on_servers).never
    @config.run "ls", :foo => "bar"
  end

  def test_put_wont_transfer_if_dry_run
    config = MockConfig.new
    config.dry_run = true
    config.servers = %w[ foo ]
    config.expects(:execute_on_servers).never
    ::Capistrano::Transfer.expects(:process).never
    config.put "foo", "bar", :mode => 0644
  end

  def test_add_default_command_options_should_return_bare_options_if_there_is_no_env_or_shell_specified
    assert_equal({:foo => "bar"}, @config.add_default_command_options(:foo => "bar"))
  end

  def test_add_default_command_options_should_merge_default_environment_as_env
    @config[:default_environment][:bang] = "baz"
    assert_equal({:foo => "bar", :env => { :bang => "baz" }}, @config.add_default_command_options(:foo => "bar"))
  end

  def test_add_default_command_options_should_merge_env_with_default_environment
    @config[:default_environment][:bang] = "baz"
    @config[:default_environment][:bacon] = "crunchy"
    assert_equal({:foo => "bar", :env => { :bang => "baz", :bacon => "chunky", :flip => "flop" }}, @config.add_default_command_options(:foo => "bar", :env => {:bacon => "chunky", :flip => "flop"}))
  end

  def test_add_default_command_options_should_use_default_shell_if_present
    @config.set :default_shell, "/bin/bash"
    assert_equal({:foo => "bar", :shell => "/bin/bash"}, @config.add_default_command_options(:foo => "bar"))
  end

  def test_add_default_command_options_should_use_shell_in_preference_of_default_shell
    @config.set :default_shell, "/bin/bash"
    assert_equal({:foo => "bar", :shell => "/bin/sh"}, @config.add_default_command_options(:foo => "bar", :shell => "/bin/sh"))
  end

  def test_default_io_proc_should_log_stdout_arguments_as_info
    ch = { :host => "capistrano",
           :server => server("capistrano"),
           :options => { :logger => mock("logger") } }
    ch[:options][:logger].expects(:info).with("data stuff", "out :: capistrano")
    MockConfig.default_io_proc[ch, :out, "data stuff"]
  end

  def test_default_io_proc_should_log_stderr_arguments_as_important
    ch = { :host => "capistrano",
           :server => server("capistrano"),
           :options => { :logger => mock("logger") } }
    ch[:options][:logger].expects(:important).with("data stuff", "err :: capistrano")
    MockConfig.default_io_proc[ch, :err, "data stuff"]
  end
end

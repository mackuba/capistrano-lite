require "utils"
require 'capistrano/configuration/connections'

class ConfigurationConnectionsTest < Test::Unit::TestCase
  class MockConfig
    attr_reader :original_initialize_called
    attr_reader :values
    attr_reader :dry_run
    attr_accessor :current_task
    attr_accessor :server

    def initialize
      @original_initialize_called = true
      @values = {}
      initialize_connections
    end

    def fetch(*args)
      @values.fetch(*args)
    end

    def [](key)
      @values[key]
    end

    def exists?(key)
      @values.key?(key)
    end

    def resolved_server
      @server
    end

    include Capistrano::Configuration::Connections
  end

  def setup
    @config = MockConfig.new
    @config.stubs(:logger).returns(stub_everything)
    Net::SSH.stubs(:configuration_for).returns({})
  end

  def test_initialize_should_initialize_session_and_call_original_initialize
    assert @config.original_initialize_called
    assert_nil @config.session
    assert_false @config.instance_variable_get('@failed')
  end

  def test_establish_connection_to_server_should_use_the_resolved_server
    Capistrano::SSH.expects(:connect).with { |s,c| s.host == "capistrano" && c == @config }.returns(:success)
    assert_nil @config.session
    @config.server = server("capistrano")
    @config.establish_connection_to_server
    assert_equal :success, @config.session
  end

  def test_establish_connection_to_server_should_not_attempt_to_reestablish_existing_connection
    Capistrano::SSH.expects(:connect).never
    @config.expects(:resolved_server).never
    @config.session = :ok
    @config.server = server("cap1")
    @config.establish_connection_to_server
    assert_equal :ok, @config.session
  end

  def test_establish_connection_to_server_should_raise_connection_error_on_failure
    Capistrano::SSH.expects(:connect).raises(Exception)
    @config.server = server("cap1")
    assert_raises(Capistrano::ConnectionError) {
      @config.establish_connection_to_server
    }
  end

  def test_connection_error_should_include_failed_host
    Capistrano::SSH.expects(:connect).raises(Exception)
    @config.server = server("cap1")
    begin
      @config.establish_connection_to_server
      flunk "expected an exception to be raised"
    rescue Capistrano::ConnectionError => e
      assert e.respond_to?(:host)
      assert_equal "cap1", e.host.to_s
    end
  end

  def test_execute_on_server_should_require_a_block
    assert_raises(ArgumentError) { @config.execute_on_server }
  end

  def test_execute_on_server_without_current_task_should_use_configured_server
    host = server("first")
    @config.server = host
    @config.expects(:establish_connection_to_server).returns(:done)
    block_called = false
    @config.execute_on_server do
      block_called = true
    end
    assert block_called
  end

  def test_execute_on_server_should_determine_server_from_configured_server
    assert_nil @config.session
    @config.server = server("cap1")
    @config.current_task = mock_task
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.execute_on_server {}
    assert_equal :success, @config.session
  end

  def test_execute_on_server_should_yield_to_block
    assert_nil @config.session
    host = server("cap1")
    @config.server = host
    @config.current_task = mock_task
    Capistrano::SSH.expects(:connect).returns(:success)
    block_called = false
    @config.execute_on_server do
      block_called = true
      assert @config.session
    end
    assert block_called
  end

  def test_execute_servers_should_raise_connection_error_on_failure_by_default
    @config.current_task = mock_task
    @config.server = server("cap1")
    Capistrano::SSH.expects(:connect).raises(Exception)
    assert_raises(Capistrano::ConnectionError) do
      @config.execute_on_server do
        flunk "expected an exception to be raised"
      end
    end
  end

  def test_execute_servers_should_not_raise_connection_error_on_failure_with_on_errors_continue
    host = server("cap1")
    @config.current_task = mock_task(:on_error => :continue)
    @config.server = host
    Capistrano::SSH.expects(:connect).raises(Exception)
    assert_nothing_raised {
      @config.execute_on_server do
        flunk "should not yield after connection failure"
      end
    }
    assert @config.instance_variable_get('@failed')
  end

  def test_execute_on_server_should_skip_failed_host_with_on_errors_continue
    @config.current_task = mock_task(:on_error => :continue)
    @config.server = server("cap1")
    @config.instance_variable_set('@failed', true)

    Capistrano::SSH.expects(:connect).never

    @config.execute_on_server do
      flunk "should not yield for failed host"
    end
  end

  def test_execute_on_server_should_record_command_errors_with_on_errors_continue
    host = server("cap1")
    @config.current_task = mock_task(:on_error => :continue)
    @config.server = host
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.execute_on_server do
      error = Capistrano::CommandError.new
      error.host = host
      raise error
    end
    assert @config.instance_variable_get('@failed')
  end

  def test_connect_should_establish_connection_to_server_in_scope
    assert_nil @config.session
    @config.current_task = mock_task
    @config.server = server("cap1")
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.connect!
    assert_equal :success, @config.session
  end

  private

  def mock_task(options = {})
    continue_on_error = options[:on_error] == :continue
    stub("task",
      :fully_qualified_name => "name",
      :options => options,
      :continue_on_error? => continue_on_error
    )
  end
end

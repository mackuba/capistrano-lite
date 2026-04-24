require "utils"
require 'capistrano/configuration/connections'

class ConfigurationConnectionsTest < Test::Unit::TestCase
  class MockConfig
    attr_reader :original_initialize_called
    attr_reader :values
    attr_reader :dry_run
    attr_accessor :current_task

    def initialize
      @original_initialize_called = true
      @values = {}
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

    include Capistrano::Configuration::Connections
  end

  def setup
    @config = MockConfig.new
    @config.stubs(:logger).returns(stub_everything)
    Net::SSH.stubs(:configuration_for).returns({})
    @ssh_options = {
      :user        => "user",
      :port        => 8080,
      :password    => "g00b3r",
      :ssh_options => { :debug => :verbose }
    }
  end

  def test_initialize_should_initialize_sessions_and_call_original_initialize
    assert @config.original_initialize_called
    assert @config.sessions.empty?
  end

  def test_connection_factory_should_return_default_connection_factory_instance
    factory = @config.connection_factory
    assert_instance_of Capistrano::Configuration::Connections::DefaultConnectionFactory, factory
  end

  def test_connection_factory_instance_should_be_cached
    assert_same @config.connection_factory, @config.connection_factory
  end

  def test_default_connection_factory_honors_config_options
    host = server("capistrano")
    Capistrano::SSH.expects(:connect).with(host, @config).returns(:session)
    assert_equal :session, @config.connection_factory.connect_to(host)
  end

  def test_should_connect_through_gateway_if_gateway_variable_is_set
    @config.values[:gateway] = "j@gateway"
    Net::SSH::Gateway.expects(:new).with("gateway", "j", :password => nil, :auth_methods => %w(publickey hostbased), :config => false).returns(stub_everything)
    assert_instance_of Capistrano::Configuration::Connections::GatewayConnectionFactory, @config.connection_factory
  end

  def test_connection_factory_as_gateway_should_honor_config_options
    @config.values[:gateway] = "gateway"
    @config.values.update(@ssh_options)
    Net::SSH::Gateway.expects(:new).with("gateway", "user", :debug => :verbose, :port => 8080, :password => nil, :auth_methods => %w(publickey hostbased), :config => false).returns(stub_everything)
    assert_instance_of Capistrano::Configuration::Connections::GatewayConnectionFactory, @config.connection_factory
  end

  def test_connection_factory_as_gateway_should_chain_gateways_if_gateway_variable_is_an_array
    @config.values[:gateway] = ["j@gateway1", "k@gateway2"]
    gateway1 = mock
    Net::SSH::Gateway.expects(:new).with("gateway1", "j", :password => nil, :auth_methods => %w(publickey hostbased), :config => false).returns(gateway1)
    gateway1.expects(:open).returns(65535)
    Net::SSH::Gateway.expects(:new).with("127.0.0.1", "k", :port => 65535, :password => nil, :auth_methods => %w(publickey hostbased), :config => false).returns(stub_everything)
    assert_instance_of Capistrano::Configuration::Connections::GatewayConnectionFactory, @config.connection_factory
  end

  def test_connection_factory_as_gateway_should_reject_gateway_hash
    @config.values[:gateway] = { "j@gateway" => "capistrano" }
    assert_raises(ArgumentError) { @config.connection_factory }
  end

  def test_connection_factory_as_gateway_should_reuse_the_gateway_for_the_single_server
    @config.values[:gateway] = "j@gateway"
    Net::SSH::Gateway.expects(:new).once.with("gateway", "j", :password => nil, :auth_methods => %w(publickey hostbased), :config => false).returns(stub_everything)
    Capistrano::SSH.stubs(:connect).returns(stub_everything)
    assert_instance_of Capistrano::Configuration::Connections::GatewayConnectionFactory, @config.connection_factory
    @config.establish_connections_to(server("capistrano"))
    @config.establish_connections_to(server("capistrano"))
  end

  def test_establish_connections_to_should_accept_a_single_server
    Capistrano::SSH.expects(:connect).with { |s,| s.host == "capistrano" }.returns(:success)
    assert @config.sessions.empty?
    @config.establish_connections_to(server("capistrano"))
    assert_equal ["capistrano"], @config.sessions.keys.map(&:host)
  end

  def test_establish_connections_to_should_reject_an_array
    assert_raises(ArgumentError) { @config.establish_connections_to([server("cap1"), server("cap2")]) }
  end

  def test_establish_connections_to_should_not_attempt_to_reestablish_existing_connection
    Capistrano::SSH.expects(:connect).never
    host = server("cap1")
    @config.sessions[host] = :ok
    @config.establish_connections_to(host)
    assert_equal %w(cap1), @config.sessions.keys.map(&:host)
  end

  def test_establish_connections_to_should_raise_connection_error_on_failure
    Capistrano::SSH.expects(:connect).raises(Exception)
    assert_raises(Capistrano::ConnectionError) {
      @config.establish_connections_to(server("cap1"))
    }
  end

  def test_connection_error_should_include_failed_host
    Capistrano::SSH.expects(:connect).raises(Exception)
    begin
      @config.establish_connections_to(server("cap1"))
      flunk "expected an exception to be raised"
    rescue Capistrano::ConnectionError => e
      assert e.respond_to?(:hosts)
      assert_equal %w(cap1), e.hosts.map { |h| h.to_s }
    end
  end

  def test_execute_on_servers_should_require_a_block
    assert_raises(ArgumentError) { @config.execute_on_servers }
  end

  def test_execute_on_servers_without_current_task_should_call_find_servers
    host = server("first")
    @config.expects(:find_servers).with(:a => :b, :c => :d).returns([host])
    @config.expects(:establish_connections_to).with(host).returns(:done)
    @config.execute_on_servers(:a => :b, :c => :d) do |result|
      assert_equal [host], result
    end
  end

  def test_execute_on_servers_without_current_task_should_raise_error_if_no_server
    @config.expects(:find_servers).with(:a => :b, :c => :d).returns([])
    assert_raises(Capistrano::NoMatchingServersError) { @config.execute_on_servers(:a => :b, :c => :d) { |list| } }
  end

  def test_execute_on_servers_should_determine_server_from_active_task
    assert @config.sessions.empty?
    @config.current_task = mock_task
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([server("cap1")])
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.execute_on_servers {}
    assert_equal %w(cap1), @config.sessions.keys.map { |s| s.host }
  end

  def test_execute_on_servers_should_yield_server_list_to_block
    assert @config.sessions.empty?
    host = server("cap1")
    @config.current_task = mock_task
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([host])
    Capistrano::SSH.expects(:connect).returns(:success)
    block_called = false
    @config.execute_on_servers do |servers|
      block_called = true
      assert_equal [host], servers
      assert @config.sessions[host]
    end
    assert block_called
  end

  def test_execute_servers_should_raise_connection_error_on_failure_by_default
    @config.current_task = mock_task
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([server("cap1")])
    Capistrano::SSH.expects(:connect).raises(Exception)
    assert_raises(Capistrano::ConnectionError) do
      @config.execute_on_servers do
        flunk "expected an exception to be raised"
      end
    end
  end

  def test_execute_servers_should_not_raise_connection_error_on_failure_with_on_errors_continue
    host = server("cap1")
    @config.current_task = mock_task(:on_error => :continue)
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([host])
    Capistrano::SSH.expects(:connect).raises(Exception)
    assert_nothing_raised {
      @config.execute_on_servers do
        flunk "should not yield after connection failure"
      end
    }
    assert @config.has_failed?(host)
  end

  def test_execute_on_servers_should_skip_failed_host_with_on_errors_continue
    host = server("cap1")
    @config.current_task = mock_task(:on_error => :continue)
    @config.failed!(host)
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([host])
    Capistrano::SSH.expects(:connect).never
    @config.execute_on_servers do
      flunk "should not yield for failed host"
    end
  end

  def test_execute_on_servers_should_record_command_errors_with_on_errors_continue
    host = server("cap1")
    @config.current_task = mock_task(:on_error => :continue)
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([host])
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.execute_on_servers do
      error = Capistrano::CommandError.new
      error.hosts = [host]
      raise error
    end
    assert @config.has_failed?(host)
  end

  def test_connect_should_establish_connection_to_server_in_scope
    assert @config.sessions.empty?
    @config.current_task = mock_task
    @config.expects(:find_servers_for_task).with(@config.current_task, {}).returns([server("cap1")])
    Capistrano::SSH.expects(:connect).returns(:success)
    @config.connect!
    assert_equal %w(cap1), @config.sessions.keys.map { |s| s.host }
  end

  private

    def mock_task(options={})
      continue_on_error = options[:on_error] == :continue
      stub("task",
        :fully_qualified_name => "name",
        :options => options,
        :continue_on_error? => continue_on_error
      )
    end
end

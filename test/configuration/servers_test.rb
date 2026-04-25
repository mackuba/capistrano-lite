require "utils"
require 'capistrano/task_definition'
require 'capistrano/configuration/servers'

class ConfigurationServersTest < Test::Unit::TestCase
  class MockConfig
    def initialize
      initialize_servers
    end

    include Capistrano::Configuration::Servers
  end

  def setup
    @config = MockConfig.new
    @config.server "app1", :user => "deploy", :port => 2222, :ssh_options => { :forward_agent => true }
  end

  def teardown
    ENV.delete('HOST')
  end

  def test_active_server_should_return_the_configured_server
    assert_equal "app1", @config.active_server.host
  end

  def test_server_should_keep_connection_options
    server = @config.active_server
    assert_equal "deploy", server.user
    assert_equal 2222, server.port
    assert_equal({ :forward_agent => true }, server.options[:ssh_options])
  end

  def test_host_environment_variable_should_replace_configured_host
    ENV['HOST'] = "override"
    server = @config.active_server
    assert_equal "override", server.host
    assert_equal "deploy", server.user
    assert_equal 2222, server.port
    assert_equal({ :forward_agent => true }, server.options[:ssh_options])
  end

  def test_host_environment_variable_can_include_user_and_port
    ENV['HOST'] = "other@override:2022"
    server = @config.active_server
    assert_equal "override", server.host
    assert_equal "other", server.user
    assert_equal 2022, server.port
  end

  def test_host_environment_variable_must_not_be_blank
    ENV['HOST'] = " "
    assert_raises(ArgumentError) { @config.active_server }
  end

  def test_active_server_should_raise_when_no_server_is_configured
    config = MockConfig.new
    assert_raises(Capistrano::NoMatchingServersError) { config.active_server }
  end

  def test_server_should_reject_multiple_hosts
    config = MockConfig.new
    assert_raises(ArgumentError) { config.server "app1", "app2" }
  end

  def test_server_should_reject_comma_separated_hosts
    config = MockConfig.new
    assert_raises(ArgumentError) { config.server "app1,app2" }
  end

  def test_server_should_reject_a_second_definition
    assert_raises(ArgumentError) { @config.server "app2" }
  end
end

require "utils"
require 'capistrano/configuration/roles'
require 'capistrano/server_definition'

class ConfigurationRolesTest < Test::Unit::TestCase
  class MockConfig
    include Capistrano::Configuration::Roles
  end

  def setup
    @config = MockConfig.new
  end

  def test_initialize_sets_nil_server
    assert_nil @config.server
  end

  def test_server_helper_sets_server_definition
    @config.server "app.example.com", :port => 2222
    assert_equal "app.example.com", @config.server.host
    assert_equal 2222, @config.server.port
  end

  def test_resolved_server_uses_variable_if_set
    @config.stubs(:exists?).with(:server).returns(true)
    @config.stubs(:fetch).with(:server).returns("from-variable.example.com")
    server = @config.resolved_server
    assert_equal "from-variable.example.com", server.host
  end
end

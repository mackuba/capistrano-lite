require "utils"
require "capistrano/configuration"

class ConfigurationServersTest < Test::Unit::TestCase
  def setup
    @config = Capistrano::Configuration.new
  end

  def test_find_servers_returns_empty_when_no_server_configured
    assert_equal [], @config.find_servers
  end

  def test_find_servers_uses_configured_server
    @config.set :server, "app.example.com"
    servers = @config.find_servers
    assert_equal 1, servers.size
    assert_equal "app.example.com", servers.first.host
  end

  def test_find_servers_accepts_explicit_hosts_option
    servers = @config.find_servers(:hosts => "override.example.com")
    assert_equal "override.example.com", servers.first.host
  end

  def test_find_servers_accepts_host_array
    servers = @config.find_servers(:hosts => %w(one two))
    assert_equal %w(one two), servers.map(&:host)
  end
end

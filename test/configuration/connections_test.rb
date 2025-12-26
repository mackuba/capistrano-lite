require "utils"
require 'capistrano/configuration/connections'

class ConfigurationConnectionsTest < Test::Unit::TestCase
  class MockConfig
    attr_reader :values

    def initialize
      @values = {}
    end

    def fetch(*args)
      @values.fetch(*args)
    end

    def [](_key); end

    def exists?(key)
      @values.key?(key)
    end

    include Capistrano::Configuration::Connections
  end

  def setup
    @config = MockConfig.new
    @config.stubs(:logger).returns(stub_everything)
    Net::SSH.stubs(:configuration_for).returns({})
  end

  def test_initialize_should_initialize_collections
    assert @config.sessions.empty?
  end

  def test_connection_factory_should_return_default_connection_factory_instance
    factory = @config.connection_factory
    assert_instance_of Capistrano::Configuration::Connections::DefaultConnectionFactory, factory
  end

  def test_establish_connections_to_opens_single_session
    server = server("capistrano")
    Capistrano::SSH.expects(:connect).with(server, @config).returns(:session)
    @config.establish_connections_to([server])
    assert_equal :session, @config.sessions[server]
  end
end

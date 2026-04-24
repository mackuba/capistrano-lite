require "utils"
require 'capistrano/task_definition'
require 'capistrano/configuration/servers'

class ConfigurationServersTest < Test::Unit::TestCase
  class MockConfig
    def initialize
      @servers = []
    end

    include Capistrano::Configuration::Servers
  end

  def setup
    @config = MockConfig.new
    @config.server "app1", :primary => true
    @config.server "app2", "app3"
    @config.server "web1", "web2"
    @config.server "file", :no_deploy => true
  end

  def test_task_without_hosts_should_apply_to_all_defined_hosts
    task = new_task(:testing)
    assert_equal %w(app1 app2 app3 web1 web2 file).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  end

  def test_task_with_hosts_option_should_apply_only_to_those_hosts
    task = new_task(:testing, @config, :hosts => %w(foo bar))
    assert_equal %w(foo bar).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  end

  def test_task_with_single_hosts_option_should_apply_only_to_that_host
    task = new_task(:testing, @config, :hosts => "foo")
    assert_equal %w(foo), @config.find_servers_for_task(task).map { |s| s.host }.sort
  end

  def test_task_with_hosts_as_environment_variable_should_apply_only_to_those_hosts
    ENV['HOSTS'] = "foo,bar"
    task = new_task(:testing)
    assert_equal %w(foo bar).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  ensure
    ENV.delete('HOSTS')
  end

  def test_task_with_hostfilter_environment_variable_should_apply_only_to_those_hosts
    ENV['HOSTFILTER'] = "app1,web1"
    task = new_task(:testing)
    assert_equal %w(app1 web1).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  ensure
    ENV.delete('HOSTFILTER')
  end

  def test_task_with_hostfilter_environment_variable_should_filter_hosts_option
    ENV['HOSTFILTER'] = "foo"
    task = new_task(:testing, @config, :hosts => %w(foo bar))
    assert_equal %w(foo).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  ensure
    ENV.delete('HOSTFILTER')
  end

  def test_task_with_hostfilter_environment_variable_and_skip_hostfilter_should_not_filter_hosts_option
    ENV['HOSTFILTER'] = "foo"
    task = new_task(:testing, @config, :hosts => %w(foo bar), :skip_hostfilter => true)
    assert_equal %w(foo bar).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  ensure
    ENV.delete('HOSTFILTER')
  end

  def test_task_with_only_should_apply_only_to_matching_hosts
    task = new_task(:testing, @config, :only => { :primary => true })
    assert_equal %w(app1), @config.find_servers_for_task(task).map { |s| s.host }
  end

  def test_task_with_except_should_apply_only_to_matching_hosts
    task = new_task(:testing, @config, :except => { :no_deploy => true })
    assert_equal %w(app1 app2 app3 web1 web2).sort, @config.find_servers_for_task(task).map { |s| s.host }.sort
  end

  def test_options_to_find_servers_for_task_should_override_options_in_task
    task = new_task(:testing, @config, :hosts => %w(foo bar))
    assert_equal %w(app1), @config.find_servers_for_task(task, :hosts => "app1").map { |s| s.host }.sort
  end

  def test_find_servers_with_hosts_nil_or_empty
    assert_equal [], @config.find_servers(:hosts => nil)
    assert_equal [], @config.find_servers(:hosts => [])
    result = @config.find_servers(:hosts => @config.find_servers(:only => { :primary => true })[0])
    assert_equal 1, result.size
    result = @config.find_servers(:hosts => "app1")
    assert_equal 1, result.size
  end

  def test_find_servers_with_lambda_for_hosts_should_raise_an_error
    assert_raises(ArgumentError) { @config.find_servers(:hosts => lambda { "foo" }) }
  end

  def test_server_with_block_should_raise_an_error
    config = MockConfig.new
    assert_raises(ArgumentError) { config.server(:dynamic => true) { %w(dynamic1 dynamic2) } }
  end
end

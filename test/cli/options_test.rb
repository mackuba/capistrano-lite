require "utils"
require "fileutils"
require 'capistrano/cli'

class CLIOptionsTest < Test::Unit::TestCase
  def setup
    @cli = Capistrano::CLI.new(%w(-T))
  end

  def test_parse_options_with_q_should_set_verbose_to_0
    @cli.args << "-q"
    @cli.parse_options!
    assert_equal 0, @cli.options[:verbose]
  end

  def test_parse_options_with_S_should_set_pre_vars
    @cli.args << "-S" << "foo=bar"
    @cli.parse_options!
    assert_equal "bar", @cli.options[:pre_vars][:foo]
  end

  def test_parse_options_should_use_config_deploy_by_default
    deploy_file = File.expand_path("config/deploy.rb")
    FileUtils.mkdir_p("config")
    File.open(deploy_file, "w") { |f| f << "# test deploy file" }

    @cli.args = %w(-T)
    @cli.parse_options!

    assert_includes @cli.options[:recipes], deploy_file
  ensure
    FileUtils.rm_f(deploy_file)
    FileUtils.rmdir("config") if File.directory?("config")
  end
end

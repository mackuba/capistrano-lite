require "utils"
require 'minestrone'

class ExtensionsTest < Test::Unit::TestCase
  module CustomExtension
    def do_something(command)
      run(command)
    end
  end

  def setup
    @config = Minestrone::Configuration.new
  end

  def teardown
    Minestrone::EXTENSIONS.keys.each { |e| Minestrone.remove_plugin(e) }
  end

  def test_register_plugin_should_add_instance_method_on_configuration_and_return_true
    assert !@config.respond_to?(:custom_stuff)
    assert Minestrone.plugin(:custom_stuff, CustomExtension)
    assert @config.respond_to?(:custom_stuff)
  end

  def test_register_plugin_that_already_exists_should_return_false
    assert Minestrone.plugin(:custom_stuff, CustomExtension)
    assert !Minestrone.plugin(:custom_stuff, CustomExtension)
  end

  def test_register_plugin_with_public_method_name_should_fail
    method = Minestrone::Configuration.public_instance_methods.first
    assert_not_nil method, "need a public instance method for testing"
    assert_raises(Minestrone::Error) { Minestrone.plugin(method, CustomExtension) }
  end

  def test_register_plugin_with_protected_method_name_should_fail
    method = Minestrone::Configuration.protected_instance_methods.first
    assert_not_nil method, "need a protected instance method for testing"
    assert_raises(Minestrone::Error) { Minestrone.plugin(method, CustomExtension) }
  end

  def test_register_plugin_with_private_method_name_should_fail
    method = Minestrone::Configuration.private_instance_methods.first
    assert_not_nil method, "need a private instance method for testing"
    assert_raises(Minestrone::Error) { Minestrone.plugin(method, CustomExtension) }
  end

  def test_unregister_plugin_that_does_not_exist_should_return_false
    assert !Minestrone.remove_plugin(:custom_stuff)
  end

  def test_unregister_plugin_should_remove_method_and_return_true
    assert Minestrone.plugin(:custom_stuff, CustomExtension)
    assert @config.respond_to?(:custom_stuff)
    assert Minestrone.remove_plugin(:custom_stuff)
    assert !@config.respond_to?(:custom_stuff)
  end

  def test_registered_plugin_proxy_should_return_proxy_object
    Minestrone.plugin(:custom_stuff, CustomExtension)
    assert_instance_of Minestrone::ExtensionProxy, @config.custom_stuff
  end

  def test_proxy_object_should_delegate_to_configuration
    Minestrone.plugin(:custom_stuff, CustomExtension)
    @config.expects(:run).with("hello")
    @config.custom_stuff.do_something("hello")
  end
end

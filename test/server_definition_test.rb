require "utils"
require 'minestrone/server_definition'

class ServerDefinitionTest < Test::Unit::TestCase
  def test_new_without_credentials_or_port_should_set_values_to_defaults
    server = Minestrone::ServerDefinition.new("www.minestrone.test")
    assert_equal "www.minestrone.test", server.host
    assert_nil   server.user
    assert_nil   server.port
  end

  def test_new_with_encoded_user_should_extract_user_and_use_default_port
    server = Minestrone::ServerDefinition.new("jamis@www.minestrone.test")
    assert_equal "www.minestrone.test", server.host
    assert_equal "jamis", server.user
    assert_nil   server.port
  end

  def test_new_with_encoded_port_should_extract_port_and_use_default_user
    server = Minestrone::ServerDefinition.new("www.minestrone.test:8080")
    assert_equal "www.minestrone.test", server.host
    assert_nil   server.user
    assert_equal 8080, server.port
  end

  def test_new_with_encoded_user_and_port_should_extract_user_and_port
    server = Minestrone::ServerDefinition.new("jamis@www.minestrone.test:8080")
    assert_equal "www.minestrone.test", server.host
    assert_equal "jamis", server.user
    assert_equal 8080, server.port
  end

  def test_new_with_user_as_option_should_use_given_user
    server = Minestrone::ServerDefinition.new("www.minestrone.test", :user => "jamis")
    assert_equal "www.minestrone.test", server.host
    assert_equal "jamis", server.user
    assert_nil   server.port
  end

  def test_new_with_port_as_option_should_use_given_user
    server = Minestrone::ServerDefinition.new("www.minestrone.test", :port => 8080)
    assert_equal "www.minestrone.test", server.host
    assert_nil   server.user
    assert_equal 8080, server.port
  end

  def test_encoded_value_should_override_hash_option
    server = Minestrone::ServerDefinition.new("jamis@www.minestrone.test:8080", :user => "david", :port => 8081)
    assert_equal "www.minestrone.test", server.host
    assert_equal "jamis", server.user
    assert_equal 8080, server.port
    assert server.options.empty?
  end

  def test_new_with_option_should_dup_option_hash
    options = {}
    server = Minestrone::ServerDefinition.new("www.minestrone.test", options)
    assert_not_equal options.object_id, server.options.object_id
  end

  def test_new_with_options_should_keep_options
    server = Minestrone::ServerDefinition.new("www.minestrone.test", :ssh_options => { :forward_agent => true })
    assert_equal({ :forward_agent => true }, server.options[:ssh_options])
  end

  def test_default_user_should_try_to_guess_username
    ENV.stubs(:[]).returns(nil)
    assert_equal "not-specified", Minestrone::ServerDefinition.default_user

    ENV.stubs(:[]).returns(nil)
    ENV.stubs(:[]).with("USERNAME").returns("ryan")
    assert_equal "ryan", Minestrone::ServerDefinition.default_user

    ENV.stubs(:[]).returns(nil)
    ENV.stubs(:[]).with("USER").returns("jamis")
    assert_equal "jamis", Minestrone::ServerDefinition.default_user
  end

  def test_comparison_should_match_when_host_user_port_are_same
    s1 = server("jamis@www.minestrone.test:8080")
    s2 = server("www.minestrone.test", :user => "jamis", :port => 8080)
    assert_equal s1, s2
    assert_equal s1.hash, s2.hash
    assert s1.eql?(s2)
  end

  def test_servers_should_be_comparable
    s1 = server("jamis@www.minestrone.test:8080")
    s2 = server("www.alphabet.test:1234")
    s3 = server("jamis@www.minestrone.test:8075")
    s4 = server("billy@www.minestrone.test:8080")

    assert s2 < s1
    assert s3 < s1
    assert s4 < s1
    assert s2 < s3
    assert s2 < s4
    assert s3 < s4
  end

  def test_comparison_should_not_match_when_any_of_host_user_port_differ
    s1 = server("jamis@www.minestrone.test:8080")
    s2 = server("bob@www.minestrone.test:8080")
    s3 = server("jamis@www.minestrone.test:8081")
    s4 = server("jamis@app.minestrone.test:8080")
    assert_not_equal s1, s2
    assert_not_equal s1, s3
    assert_not_equal s1, s4
    assert_not_equal s2, s3
    assert_not_equal s2, s4
    assert_not_equal s3, s4
  end

  def test_to_s
    assert_equal "www.minestrone.test", server("www.minestrone.test").to_s
    assert_equal "www.minestrone.test", server("www.minestrone.test:22").to_s
    assert_equal "www.minestrone.test:1234", server("www.minestrone.test:1234").to_s
    assert_equal "jamis@www.minestrone.test", server("jamis@www.minestrone.test").to_s
    assert_equal "jamis@www.minestrone.test:1234", server("jamis@www.minestrone.test:1234").to_s
  end
end

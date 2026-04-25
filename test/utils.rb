require 'rubygems'
require 'bundler/setup'

require 'test/unit'
require 'mocha'

require 'capistrano/server_definition'

module TestExtensions
  def server(host, options = {})
    Capistrano::ServerDefinition.new(host, options)
  end

  def namespace(fqn = nil)
    space = stub(:fully_qualified_name => fqn, :default_task => nil)
    yield(space) if block_given?
    space
  end

  def new_task(name, namespace = @namespace, options = {}, &block)
    block ||= Proc.new {}
    task = Capistrano::TaskDefinition.new(name, namespace, options, &block)
    assert_equal block, task.body
    return task
  end
end

class Test::Unit::TestCase
  include TestExtensions
end

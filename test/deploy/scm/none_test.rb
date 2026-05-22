require 'utils'
require 'minestrone/recipes/deploy/scm/none'

class DeploySCMNoneTest < Test::Unit::TestCase
  class TestSCM < Minestrone::Deploy::SCM::None
    default_command 'none'
  end

  def setup
    @config = {}
    def @config.exists?(name); key?(name); end
    @source = TestSCM.new(@config)
  end

  def test_the_truth
    assert true
  end

  def test_checkout
    @config[:repository] = '.'
    rev = ''
    dest = '/var/www'
    assert_equal "cp -R . /var/www", @source.checkout(rev, dest)
  end

end

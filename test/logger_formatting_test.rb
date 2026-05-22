require File.expand_path("../utils", __FILE__)
require 'minestrone/logger'
require 'stringio'

Minestrone::Logger.class_eval do
  # Allows formatters to be changed during tests
  def self.formatters=(formatters)
    @formatters = formatters
    @sorted_formatters = nil
  end
end

class LoggerFormattingTest < Test::Unit::TestCase
  def setup
    @io = StringIO.new
    @io.stubs(:tty?).returns(true)
    @logger = Minestrone::Logger.new(:output => @io, :level => 3)
  end

  def test_matching_with_style_and_color
    Minestrone::Logger.formatters = [{ :match => /^err ::/, :color => :red, :style => :underscore, :level => 0 }]
    @logger.log(0, "err :: Error Occurred")
    assert @io.string.include? "\e[4;31merr :: Error Occurred\e[0m"
  end

  def test_style_without_color
    Minestrone::Logger.formatters = [{ :match => /.*/, :style => :underscore, :level => 0 }]
    @logger.log(0, "test message")
    # Default color should be blank (0m)
    assert @io.string.include? "\e[4;0mtest message\e[0m"
  end

  def test_prepending_text
    Minestrone::Logger.formatters = [{ :match => /^executing/, :level => 0, :prepend => '== Currently ' }]
    @logger.log(0, "executing task")
    assert @io.string.include? '== Currently executing task'
  end

  def test_replacing_matched_text
    Minestrone::Logger.formatters = [{ :match => /^executing/, :level => 0, :replace => 'running' }]
    @logger.log(0, "executing task")
    assert @io.string.include? 'running task'
  end

  def test_prepending_timestamps
    Minestrone::Logger.formatters = [{ :match => /.*/, :level => 0, :timestamp => true }]
    @logger.log(0, "test message")
    assert @io.string.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} test message/)
  end

  def test_formatter_priorities
    Minestrone::Logger.formatters = [
      { :match => /.*/, :color => :red,  :level => 0, :priority => -10 },
      { :match => /.*/, :color => :blue, :level => 0, :priority => -20, :prepend => '###' }
    ]

    @logger.log(0, "test message")
    # Only the red formatter (color 31) should be applied.
    assert @io.string.include? "\e[31mtest message"
    # The blue formatter should not have prepended $$$
    assert !@io.string.include?('###')
  end

  def test_no_formatting_if_no_color_or_style
    Minestrone::Logger.formatters = []
    @logger.log(0, "test message")
    assert @io.string.include? "*** test message"
  end

  def test_formatter_log_levels
    Minestrone::Logger.formatters = [{ :match => /.*/, :color => :blue, :level => 3 }]
    @logger.log(0, "test message")
    # Should not match log level
    assert @io.string.include? "*** test message"

    clear_logger
    @logger.log(3, "test message")
    # Should match log level and apply blue color
    assert @io.string.include? "\e[34mtest message"
  end

  private

  def colorize(message, color, style = nil)
    style = "#{style};" if style
    "\e[#{style}#{color}m" + message + "\e[0m"
  end

  def clear_logger
    @io = StringIO.new
    @io.stubs(:tty?).returns(true)
    @logger.device = @io
  end
end

class DefaultLoggerFormattersTest < Test::Unit::TestCase
  def setup
    @expected_default_formatter_values = [
      # TRACE
      { :match => /command finished/,          :color => :white,   :style => :dim, :level => 3, :priority => -10 },
      { :match => /executing locally/,         :color => :yellow,  :level => 3, :priority => -20 },

      # DEBUG
      { :match => /executing `.*/,             :color => :green,   :level => 2, :priority => -10, :timestamp => true },
      { :match => /.*/,                        :color => :yellow,  :level => 2, :priority => -30 },

      # INFO
      { :match => /.*out\] (fatal:|ERROR:).*/, :color => :red,     :level => 1, :priority => -10 },
      { :match => /Permission denied/,         :color => :red,     :level => 1, :priority => -20 },
      { :match => /sh: .+: command not found/, :color => :magenta, :level => 1, :priority => -30 },

      # IMPORTANT
      { :match => /^err ::/,                   :color => :red,     :level => 0, :priority => -10 },
      { :match => /.*/,                        :color => :blue,    :level => 0, :priority => -20 }
    ]

    @custom_default_formatter_values = [
      { :match => /.*/,  :color => :white }
    ]

  end

  def test_default_formatters_api
    assert Minestrone::Logger.respond_to? :default_formatters
    assert Minestrone::Logger.respond_to? :default_formatters=
  end

  def test_default_formatters_values
    assert_equal @expected_default_formatter_values, Minestrone::Logger.default_formatters
    assert_equal @expected_default_formatter_values, Minestrone::Logger.instance_variable_get("@formatters")
    assert_equal nil, Minestrone::Logger.instance_variable_get("@sorted_formatters")
  end

  def test_set_default_formatters_values
    # when given an array
    Minestrone::Logger.default_formatters = @custom_default_formatter_values

    assert_equal @custom_default_formatter_values, Minestrone::Logger.default_formatters
    Minestrone::Logger.default_formatters = @custom_default_formatter_values
    assert_equal @custom_default_formatter_values, Minestrone::Logger.instance_variable_get("@formatters")
    assert_equal nil, Minestrone::Logger.instance_variable_get("@sorted_formatters")

    # when given a single formatter values hash
    Minestrone::Logger.default_formatters = @custom_default_formatter_values.first

    assert_equal @custom_default_formatter_values, Minestrone::Logger.default_formatters
  end

end

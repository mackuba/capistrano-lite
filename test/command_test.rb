require "utils"
require 'capistrano/command'
require 'capistrano/configuration'

class CommandTest < Test::Unit::TestCase
  class FakeChannel < Hash
    def exec(*); end
    def send_data(*); end
    def eof!; end
    def close; end
    def request_pty(*); end
    def on_data(*); end
    def on_extended_data(*); end
    def on_request(*); end
    def on_close(*); end
  end

  def test_command_should_keep_session
    session = mock_session
    assert_equal session, Capistrano::Command.new("ls", session).session
  end

  def test_command_with_newlines_should_be_properly_escaped
    cmd = Capistrano::Command.new("ls\necho", mock_session)
    assert_equal "ls\\\necho", cmd.command
  end

  def test_command_with_crlf_newlines_should_be_properly_escaped
    cmd = Capistrano::Command.new("ls\r\necho", mock_session)
    assert_equal "ls\\\necho", cmd.command
  end

  def test_command_with_pty_should_request_pty_and_register_success_callback
    session = setup_for_extracting_channel_action(:request_pty, true) do |ch|
      ch.expects(:exec).with(%(sh -c 'ls'))
    end
    open_test_channel("ls", session, :pty => true)
  end

  def test_command_with_env_key_should_have_environment_constructed_and_prepended
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:request_pty).never
      ch.expects(:exec).with(%(env FOO=bar sh -c 'ls'))
    end
    open_test_channel("ls", session, :env => { "FOO" => "bar" })
  end

  def test_env_with_symbolic_key_should_be_accepted_as_a_string
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(env FOO=bar sh -c 'ls'))
    end
    open_test_channel("ls", session, :env => { :FOO => "bar" })
  end

  def test_env_as_string_should_be_substituted_in_directly
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(env HOWDY=there sh -c 'ls'))
    end
    open_test_channel("ls", session, :env => "HOWDY=there")
  end

  def test_env_with_symbolic_value_should_be_accepted_as_string
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(env FOO=bar sh -c 'ls'))
    end
    open_test_channel("ls", session, :env => { "FOO" => :bar })
  end

  def test_env_value_should_be_escaped
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(env FOO=(\\ \\\"bar\\\"\\ ) sh -c 'ls'))
    end
    open_test_channel("ls", session, :env => { "FOO" => '( "bar" )' })
  end

  def test_env_with_multiple_keys_should_chain_the_entries_together
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with do |command|
        command =~ /^env / &&
        command =~ /\ba=b\b/ &&
        command =~ /\bc=d\b/ &&
        command =~ /\be=f\b/ &&
        command =~ / sh -c 'ls'$/
      end
    end
    open_test_channel("ls", session, :env => { :a => :b, :c => :d, :e => :f })
  end

  def test_open_channel_should_set_host_key_on_channel
    channel = nil
    session = setup_for_extracting_channel_action { |ch| channel = ch }
    open_test_channel("ls", session)
    assert_equal "capistrano", channel[:host]
  end

  def test_open_channel_should_set_options_key_on_channel
    channel = nil
    session = setup_for_extracting_channel_action { |ch| channel = ch }
    open_test_channel("ls", session, :data => "here we go")
    assert_equal({ :data => 'here we go' }, channel[:options])
  end

  def test_successful_channel_should_send_command
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(sh -c 'ls'))
    end
    open_test_channel("ls", session)
  end

  def test_successful_channel_with_shell_option_should_send_command_via_specified_shell
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(/bin/bash -c 'ls'))
    end
    open_test_channel("ls", session, :shell => "/bin/bash")
  end

  def test_successful_channel_with_shell_false_should_send_command_without_shell
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(echo `hostname`))
    end
    open_test_channel("echo `hostname`", session, :shell => false)
  end

  def test_successful_channel_should_send_data_if_data_key_is_present
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(sh -c 'ls'))
      ch.expects(:send_data).with("here we go")
    end
    open_test_channel("ls", session, :data => "here we go")
  end

  def test_unsuccessful_pty_request_should_close_channel
    session = setup_for_extracting_channel_action(:request_pty, false) do |ch|
      ch.expects(:close)
    end
    open_test_channel("ls", session, :pty => true)
  end

  def test_on_data_should_invoke_callback_as_stdout
    session = setup_for_extracting_channel_action(:on_data, "hello")
    called = false
    open_test_channel("ls", session) do |ch, stream, data|
      called = true
      assert_equal :out, stream
      assert_equal "hello", data
    end
    assert called
  end

  def test_on_extended_data_should_invoke_callback_as_stderr
    session = setup_for_extracting_channel_action(:on_extended_data, 2, "hello")
    called = false
    open_test_channel("ls", session) do |ch, stream, data|
      called = true
      assert_equal :err, stream
      assert_equal "hello", data
    end
    assert called
  end

  def test_on_request_should_record_exit_status
    data = mock(:read_long => 5)
    channel = nil
    session = setup_for_extracting_channel_action([:on_request, "exit-status"], data) { |ch| channel = ch }
    open_test_channel("ls", session)
    assert_equal 5, channel[:status]
  end

  def test_on_request_should_log_exit_signal_if_logger_present
    data = mock(:read_string => "TERM")
    logger = stub_everything

    session = setup_for_extracting_channel_action([:on_request, "exit-signal"], data)
    logger.expects(:important).with("command received signal TERM", server("capistrano"))

    open_test_channel("puppet", session, :logger => logger)
  end

  def test_on_close_should_set_channel_closed
    channel = nil
    session = setup_for_extracting_channel_action(:on_close) { |ch| channel = ch }
    open_test_channel("ls", session)
    assert channel[:closed]
  end

  def test_stop_should_close_open_channel
    cmd = Capistrano::Command.new("ls", mock_session)
    cmd.send(:open_channel, mock_session(new_channel(false)))
    cmd.stop!
  end

  def test_process_should_return_cleanly_if_channel_has_zero_exit_status
    cmd = Capistrano::Command.new("ls", mock_session(new_channel(true, 0)))
    assert_nothing_raised { cmd.process! }
  end

  def test_process_should_raise_error_if_channel_has_non_zero_exit_status
    cmd = Capistrano::Command.new("ls", mock_session(new_channel(true, 1)))
    assert_raises(Capistrano::CommandError) { cmd.process! }
  end

  def test_command_error_should_include_accessor_with_host_array
    cmd = Capistrano::Command.new("ls", mock_session(new_channel(true, 1)))

    begin
      cmd.process!
      flunk "expected an exception to be raised"
    rescue Capistrano::CommandError => e
      assert e.respond_to?(:hosts)
      assert_equal %w(capistrano), e.hosts.map { |h| h.to_s }
    end
  end

  def test_process_should_loop_until_channel_is_closed
    ch = mock("channel")
    ch.stubs(:to_ary)
    ch.stubs(:[]).with(:closed).returns(false, false, false, true)
    ch.expects(:[]).with(:status).returns(0)
    cmd = Capistrano::Command.new("ls", mock_session(ch))
    assert_nothing_raised do
      cmd.process!
    end
  end

  def test_process_should_instantiate_command_and_process!
    cmd = mock("command", :process! => nil)
    session = mock_session
    Capistrano::Command.expects(:new).with("ls -l", session, {:foo => "bar"}).returns(cmd)
    Capistrano::Command.process("ls -l", session, :foo => "bar")
  end

  def test_process_with_host_placeholder_should_substitute_host_placeholder_with_each_host
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(sh -c 'echo capistrano'))
    end
    open_test_channel("echo $CAPISTRANO:HOST$", session)
  end

  def test_process_with_unknown_placeholder_should_not_replace_placeholder
    session = setup_for_extracting_channel_action do |ch|
      ch.expects(:exec).with(%(sh -c 'echo $CAPISTRANO:OTHER$'))
    end
    open_test_channel("echo $CAPISTRANO:OTHER$", session)
  end

  def test_input_stream_closed_when_eof_option_is_true
    channel = nil
    session = setup_for_extracting_channel_action { |ch| channel = ch }
    channel.expects(:eof!)
    open_test_channel("cat", session, :data => "here we go", :eof => true)
    assert_equal({ :data => 'here we go', :eof => true }, channel[:options])
  end

  private

  def mock_session(channel = nil)
    stub('session',
         :open_channel => channel,
         :preprocess   => true,
         :postprocess  => true,
         :listeners    => {},
         :xserver      => server("capistrano"))
  end

  class MockChannel < Hash
    def close
    end
  end

  def new_channel(closed, status = nil)
    ch = MockChannel.new
    ch.update({ :closed => closed, :host => "capistrano", :server => server("capistrano") })
    ch[:status] = status if status
    ch.expects(:close) unless closed
    ch
  end

  def setup_for_extracting_channel_action(action = nil, *args)
    s = server("capistrano")
    session = mock("session", :xserver => s)

    channel = FakeChannel.new
    session.expects(:open_channel).yields(channel)

    channel.stubs(:on_data)
    channel.stubs(:on_extended_data)
    channel.stubs(:on_request)
    channel.stubs(:on_close)

    if action
      action = Array(action)
      channel.expects(action.first).with(*action[1..-1]).yields(channel, *args)
    end

    yield channel if block_given?

    session
  end

  def open_test_channel(command, session, options = {}, &block)
    cmd = Capistrano::Command.new(command, session, options, &block)
    cmd.send(:open_channel, session)
    cmd
  end
end

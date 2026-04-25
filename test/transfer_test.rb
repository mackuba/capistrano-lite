require 'utils'
require 'capistrano/transfer'

class TransferTest < Test::Unit::TestCase
  def test_class_process_should_delegate_to_instance_process
    s = session('app1')
    Capistrano::Transfer.expects(:new).with(:up, "from", "to", s, {}).returns(mock('transfer', :process! => nil)).yields
    yielded = false
    Capistrano::Transfer.process(:up, "from", "to", s, {}) { yielded = true }
    assert yielded
  end

  def test_default_transport_is_sftp
    transfer = Capistrano::Transfer.new(:up, "from", "to", session('app1', :sftp))
    assert_equal :sftp, transfer.transport
  end

  def test_active_is_true_when_sftp_transfer_is_active
    s = session('app1', :sftp)
    s.xsftp.expects(:upload).returns(stub('operation', :active? => true))
    transfer = Capistrano::Transfer.new(:up, "from", "to", s, :via => :sftp)
    assert_equal true, transfer.active?
  end

  def test_active_is_false_when_sftp_transfer_is_not_active
    s = session('app1', :sftp)
    s.xsftp.expects(:upload).returns(stub('operation', :active? => false))
    transfer = Capistrano::Transfer.new(:up, "from", "to", s, :via => :sftp)
    assert_equal false, transfer.active?
  end

  def test_active_is_true_when_scp_transfer_is_active
    s = session('app1', :scp)
    channel = stub('channel', :[]= => nil, :active? => true)
    s.scp.expects(:upload).returns(channel)
    transfer = Capistrano::Transfer.new(:up, "from", "to", s, :via => :scp)
    assert_equal true, transfer.active?
  end

  def test_active_is_false_when_scp_transfer_is_not_active
    s = session('app1', :scp)
    channel = stub('channel', :[]= => nil, :active? => false)
    s.scp.expects(:upload).returns(channel)
    transfer = Capistrano::Transfer.new(:up, "from", "to", s, :via => :scp)
    assert_equal false, transfer.active?
  end

  [:up, :down].each do |direction|
    define_method("test_sftp_#{direction}load_from_file_to_file_should_normalize_from_and_to") do
      s = session('app1', :sftp)

      s.xsftp.expects("#{direction}load".to_sym).with("from-#{s.xserver.host}", "to-#{s.xserver.host}",
        :properties => { :server => s.xserver, :host => s.xserver.host })

      transfer = Capistrano::Transfer.new(direction, "from-$CAPISTRANO:HOST$", "to-$CAPISTRANO:HOST$", s)
    end

    define_method("test_scp_#{direction}load_from_file_to_file_should_normalize_from_and_to") do
      s = session('app1', :scp)

      s.scp.expects("#{direction}load".to_sym).returns({}).with("from-#{s.xserver.host}", "to-#{s.xserver.host}", :via => :scp)

      transfer = Capistrano::Transfer.new(direction, "from-$CAPISTRANO:HOST$", "to-$CAPISTRANO:HOST$", s, :via => :scp)
    end
  end

  def test_sftp_upload_from_IO_to_file_should_clone_the_IO_for_the_connection
    s = session('app1', :sftp)
    io = StringIO.new("from here")

    s.xsftp.expects(:upload).with do |from, to, opts|
      from != io && from.is_a?(StringIO) && from.string == io.string &&
      to == "/to/here-#{s.xserver.host}" &&
      opts[:properties][:server] == s.xserver &&
      opts[:properties][:host] == s.xserver.host
    end

    transfer = Capistrano::Transfer.new(:up, StringIO.new("from here"), "/to/here-$CAPISTRANO:HOST$", s)
  end

  def test_scp_upload_from_IO_to_file_should_clone_the_IO_for_the_connection
    s = session('app1', :scp)
    io = StringIO.new("from here")

    channel = mock('channel')
    channel.expects(:[]=).with(:server, s.xserver)
    channel.expects(:[]=).with(:host, s.xserver.host)
    s.scp.expects(:upload).returns(channel).with do |from, to, opts|
      from != io && from.is_a?(StringIO) && from.string == io.string &&
      to == "/to/here-#{s.xserver.host}"
    end

    transfer = Capistrano::Transfer.new(:up, StringIO.new("from here"), "/to/here-$CAPISTRANO:HOST$", s, :via => :scp)
  end

  def test_process_should_block_until_transfer_is_no_longer_active
    transfer = Capistrano::Transfer.new(:up, "from", "to", session('app1', :sftp))
    transfer.expects(:process_iteration).times(4).yields.returns(true,true,true,false)
    transfer.expects(:active?).times(4)
    transfer.process!
  end

  def test_errors_raised_for_a_sftp_session_should_abort_transfer
    s = session('app1')
    error = ExceptionWithSession.new(s)
    transfer = Capistrano::Transfer.new(:up, "from", "to", session('app1', :sftp))
    transfer.expects(:process_iteration).raises(error).times(3).returns(true, false)
    txfr = mock('transfer', :abort! => true)
    txfr.expects(:[]=).with(:failed, true)
    txfr.expects(:[]=).with(:error, error)
    txfr.stubs(:[]).with(:failed).returns(true)
    txfr.stubs(:[]).with(:server).returns(s.xserver)
    txfr.stubs(:[]).with(:error).returns(error)
    transfer.expects(:transfer).returns(txfr).at_least_once
    assert_raises(Capistrano::TransferError) { transfer.process! }
  end

  def test_errors_raised_for_a_scp_session_should_abort_transfer
    s = session('app1')
    error = ExceptionWithSession.new(s)
    transfer = Capistrano::Transfer.new(:up, "from", "to", session('app1', :scp), :via => :scp)
    transfer.expects(:process_iteration).raises(error).times(3).returns(true, false)
    txfr = mock('channel', :close => true)
    txfr.expects(:[]=).with(:failed, true)
    txfr.expects(:[]=).with(:error, error)
    txfr.stubs(:[]).with(:failed).returns(true)
    txfr.stubs(:[]).with(:server).returns(s.xserver)
    txfr.stubs(:[]).with(:error).returns(error)
    transfer.expects(:transfer).returns(txfr).at_least_once
    assert_raises(Capistrano::TransferError) { transfer.process! }
  end

  def test_uploading_a_non_existing_file_should_raise_an_understandable_error
    s = session('app1')
    error = Capistrano::Processable::SessionAssociation.on(ArgumentError.new('expected a file to upload'), s)
    transfer = Capistrano::Transfer.new(:up, "from", "to", session('app1', :scp), :via => :scp)
    transfer.expects(:process_iteration).raises(error)
    assert_raise(ArgumentError, 'expected a file to upload') { transfer.process! }
  end

  private

    class ExceptionWithSession < ::Exception
      attr_reader :session

      def initialize(session)
        @session = session
        super()
      end
    end

    def session(host, mode=nil)
      session = stub('session', :xserver => stub('server', :host => host))
      case mode
      when :sftp
        sftp = stub('sftp')
        session.expects(:sftp).with(false).returns(sftp)
        sftp.expects(:connect).yields(sftp).returns(sftp)
        operation = stub('operation', :active? => false, :[] => nil)
        sftp.stubs(:upload).returns(operation)
        sftp.stubs(:download).returns(operation)
        session.stubs(:xsftp).returns(sftp)
      when :scp
        channel = stub('channel', :[]= => nil, :[] => nil, :active? => false, :close => true)
        scp = stub('scp')
        scp.stubs(:upload).returns(channel)
        scp.stubs(:download).returns(channel)
        session.stubs(:scp).returns(scp)
      end
      session
    end
end

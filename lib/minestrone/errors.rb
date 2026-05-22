module Minestrone
  Error = Class.new(RuntimeError)

  CaptureError            = Class.new(Minestrone::Error)
  NoSuchTaskError         = Class.new(Minestrone::Error)
  NoMatchingServersError  = Class.new(Minestrone::Error)

  class RemoteError < Error
    attr_accessor :host
  end

  ConnectionError     = Class.new(Minestrone::RemoteError)
  TransferError       = Class.new(Minestrone::RemoteError)
  CommandError        = Class.new(Minestrone::RemoteError)

  LocalArgumentError  = Class.new(Minestrone::Error)
end

module Capistrano
  module Processable
    module SessionAssociation
      def self.on(exception, session)
        unless exception.respond_to?(:session)
          exception.extend(self)
          exception.session = session
        end

        return exception
      end

      attr_accessor :session
    end

    def process_iteration(wait = nil, &block)
      ensure_session { |session| session.preprocess }

      return false if block && !block.call(self)

      readers = session.listeners.keys.reject { |io| io.closed? }
      writers = readers.select { |io| io.respond_to?(:pending_write?) && io.pending_write? }

      if readers.any? || writers.any?
        readers, writers, = IO.select(readers, writers, nil, wait)
      else
        return false
      end

      if readers
        ensure_session do |session|
          ios = session.listeners.keys
          session.postprocess(ios & readers, ios & writers)
        end
      end

      true
    end

    def ensure_session
      begin
        yield session
      rescue Exception => error
        raise SessionAssociation.on(error, session)
      end
      session
    end
  end
end

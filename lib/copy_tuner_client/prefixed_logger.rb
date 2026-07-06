module CopyTunerClient
  class PrefixedLogger
    attr_reader :prefix, :original_logger

    def initialize(prefix, logger)
      @prefix          = prefix
      @original_logger = logger
    end

    def info(message = nil, &)
      log(:info, message, &)
    end

    def debug(message = nil, &)
      log(:debug, message, &)
    end

    def warn(message = nil, &)
      log(:warn, message, &)
    end

    def error(message = nil, &)
      log(:error, message, &)
    end

    def fatal(message = nil, &)
      log(:fatal, message, &)
    end

    def flush
      original_logger.flush if original_logger.respond_to?(:flush)
    end

    private

    def log(severity, message, &)
      prefixed_message = "#{prefix} #{thread_info} #{message}"
      original_logger.send(severity, prefixed_message, &)
    end

    def thread_info
      "[P:#{Process.pid}] [T:#{Thread.current.object_id}]"
    end
  end
end

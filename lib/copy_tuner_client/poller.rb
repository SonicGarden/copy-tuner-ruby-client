require 'copy_tuner_client/cache'
require 'copy_tuner_client/queue_with_timeout'

module CopyTunerClient
  # Starts a background thread that continually resynchronizes with the remote
  # server using the given {Cache} after a set delay.
  class Poller
    # @param options [Hash]
    # @option options [Logger] :logger where errors should be logged
    # @option options [Fixnum] :polling_delay how long to wait in between requests
    def initialize(cache, options)
      @cache         = cache
      @polling_delay = options[:polling_delay]
      @logger        = options[:logger]
      @command_queue = CopyTunerClient::QueueWithTimeout.new
      @mutex         = Mutex.new
      @thread        = nil
      @pid           = nil
    end

    def start
      @mutex.synchronize do
        # スレッドは fork を越えて引き継がれないため、前プロセスの Thread オブジェクトは
        # 死んでいるものとして捨て、張り直す
        @thread = nil if forked?

        if @thread.nil?
          @pid = Process.pid
          @logger.info 'start poller thread'
          @thread = Thread.new { poll } or logger.error("Couldn't start poller thread")
        end
      end
    end

    def stop
      @mutex.synchronize do
        # 積んだ :stop は pop されるまでキューに残るため、止める相手のスレッドが自プロセスに
        # ある場合のみ積む。さもないと直後に start した新しいスレッドが 1 周目でそれを pop して
        # 自分を止めてしまう（スレッド未起動のとき / fork 後の子プロセスのときが該当）
        if @thread && !forked?
          @command_queue.uniq_push(:stop)
          @thread.join
        end

        @thread = nil
        @pid = nil
      end
    end

    def start_sync
      @command_queue.uniq_push(:sync)
    end

    def wait_for_download
      @cache.wait_for_download
    end

    private

    attr_reader :cache, :logger, :polling_delay

    def forked?
      !@pid.nil? && @pid != Process.pid
    end

    def poll
      loop do
        cache.sync
        logger.flush if logger.respond_to?(:flush)
        begin
          command = @command_queue.pop_with_timeout(polling_delay)
          break if command == :stop
        rescue ThreadError
          # timeout
        end
      end
      @logger.info 'stop poller thread'
    rescue InvalidApiKey => e
      logger.error(e.message)
    end
  end
end

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
      @cache          = cache
      @polling_delay  = options[:polling_delay]
      @logger         = options[:logger]
      @command_queue  = CopyTunerClient::QueueWithTimeout.new
      @mutex          = Mutex.new
      @thread         = nil
      @last_synced_at = nil
    end

    def start
      @mutex.synchronize do
        if @thread.nil?
          @logger.info 'start poller thread'
          @thread = Thread.new { poll } or logger.error("Couldn't start poller thread")
        end
      end
    end

    # @return [Boolean] 動いていたスレッドを停止したなら +true+
    def stop
      @mutex.synchronize do
        # 積んだ :stop は pop されるまでキューに残るため、止める相手のスレッドがあるときだけ積む。
        # さもないと次に start したスレッドが 1 周目でそれを pop して自分を止めてしまう
        next false if @thread.nil?

        @command_queue.uniq_push(:stop)
        @thread.join
        @thread = nil
        true
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

    def poll
      timeout = remaining_delay
      until wait_for_command(timeout) == :stop
        sync
        timeout = polling_delay
      end
      logger.info 'stop poller thread'
    rescue InvalidApiKey => e
      logger.error(e.message)
    rescue StandardError => e
      # 例外はスレッドの外へ漏らさない。stop の join は fork の直前にも呼ばれるため、
      # 漏らすと poller の失敗がアプリ側の fork まで巻き添えにする
      logger.error("poller thread aborted: #{e.class}: #{e.message}")
    end

    def sync
      cache.sync
      @last_synced_at = monotonic_now
      logger.flush if logger.respond_to?(:flush)
    end

    # 最初の待ち時間を「前回 sync からの残り」にすることで、stop / start を繰り返しても
    # sync の間隔を保つ。fork のたびに stop / start されるので、これが無いと worker を
    # fork する数だけ親プロセスで sync（HTTP 往復）が走り直し、その分 join も待たされる。
    # 基点には NTP や手動の時刻変更で巻き戻らない CLOCK_MONOTONIC を使う
    # （Time.now だと時計が後ろに飛んだぶんだけ待ち時間が伸びて同期が止まる）
    def remaining_delay
      return 0 if @last_synced_at.nil?

      remaining = polling_delay - (monotonic_now - @last_synced_at)
      remaining.negative? ? 0 : remaining
    end

    def wait_for_command(timeout)
      @command_queue.pop_with_timeout(timeout)
    rescue ThreadError
      nil # timeout
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

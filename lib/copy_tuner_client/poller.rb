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
      # スレッドの生死とは別に、ライフサイクルの意図を持つ。
      # @running: ポーリングを継続する意図があるか（start で true / stop で false）
      # @aborted: 張り直しても同じ理由で死ぬと分かっている終わり方をしたか
      @running        = false
      @aborted        = false
    end

    def start
      @mutex.synchronize do
        @running = true
        # 回復の見込みがない理由で終了しているなら張り直さない。fork のたびに同じ例外で
        # 死ぬスレッドを作り直してログを埋めるだけになる
        next if @aborted
        # fork 後の子は親から dead な Thread オブジェクトを継承するため、nil かどうかだけでは
        # 「動いていない」を判定できない。死んでいるスレッドは張り直す
        next if @thread&.alive?

        # コマンドキューは世代ごとに作り直し、スレッドに自分のキューを渡す。前の世代宛に
        # 積まれたまま未消費で残った :stop を次の世代が 1 周目で拾って自殺するのを、
        # 「1 つのキューは 1 本のスレッドだけのもの」という不変条件で構造的に防ぐ
        queue = CopyTunerClient::QueueWithTimeout.new
        @command_queue = queue
        @logger.info 'start poller thread'
        @thread = Thread.new { poll(queue) } or logger.error("Couldn't start poller thread")
      end
    end

    # 戻り値は ForkHook が「fork 後に張り直すか」を決めるのに使う。スレッドの生死ではなく
    # ポーリングを継続する意図があったかを返す。想定外の例外で死んだだけのスレッドは
    # fork 後に張り直したいが、生死で判定すると張り直せなくなる
    #
    # @return [Boolean] ポーリング継続の意図があった（＝ fork 後に張り直すべき）なら +true+
    def stop
      @mutex.synchronize do
        resumable = @running && !@aborted
        @running = false

        thread = @thread
        @thread = nil
        # 例外で終わったスレッドは非 nil のまま dead で残る。それに :stop を積んでも誰も
        # pop しないので、生きているときだけ積んで待つ
        if thread&.alive?
          @command_queue.uniq_push(:stop)
          thread.join
        end

        resumable
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

    def poll(queue)
      timeout = remaining_delay
      until wait_for_command(queue, timeout) == :stop
        sync
        timeout = polling_delay
      end
      logger.info 'stop poller thread'
    rescue InvalidApiKey => e
      # キーが不正なら張り直しても同じ結果になるので、以後の再開を止める
      @aborted = true
      logger.error(e.message)
    rescue StandardError => e
      # 例外はスレッドの外へ漏らさない。stop の join は fork の直前にも呼ばれるため、
      # 漏らすと poller の失敗がアプリ側の fork まで巻き添えにする。
      # ここで握ると report_on_exception による stderr 出力も消えるので backtrace を残す
      logger.error("poller thread aborted: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
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

    # 自分の世代のキューを受け取る。@command_queue は start のたびに差し替わるため、
    # 終了処理中の古いスレッドが新しい世代のキューを覗いてしまわないようにする
    def wait_for_command(queue, timeout)
      queue.pop_with_timeout(timeout)
    rescue ThreadError
      nil # timeout
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

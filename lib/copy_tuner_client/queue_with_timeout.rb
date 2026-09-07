module CopyTunerClient
  # https://spin.atomicobject.com/2014/07/07/ruby-queue-pop-timeout/
  class QueueWithTimeout
    def initialize
      @mutex = Mutex.new
      @queue = []
      @received = ConditionVariable.new
    end

    def <<(item)
      @mutex.synchronize do
        @queue << item
        @received.signal
      end
    end

    def uniq_push(item)
      @mutex.synchronize do
        unless @queue.member?(item)
          @queue << item
          @received.signal
        end
      end
    end

    def pop(non_block = false)
      pop_with_timeout(non_block ? 0 : nil)
    end

    def pop_with_timeout(timeout = nil)
      @mutex.synchronize do
        wait_for_item(timeout)

        # if we're still empty after the timeout, raise exception
        raise ThreadError, 'queue empty' if @queue.empty?

        @queue.shift
      end
    end

    private

    def wait_for_item(timeout)
      if timeout.nil?
        # wait indefinitely until there is an element in the queue
        @received.wait(@mutex) while @queue.empty?
      elsif @queue.empty? && timeout != 0
        wait_with_timeout(timeout)
      end
    end

    def wait_with_timeout(timeout)
      # wait for element or timeout
      # NTP の step 補正や手動の時刻変更で巻き戻らない CLOCK_MONOTONIC で締め切りを測る。
      # ウォールクロックだと時計が後ろへ飛んだぶんだけ待ち時間が伸びる
      deadline = monotonic_now + timeout
      while @queue.empty? && (remaining_time = deadline - monotonic_now).positive?
        @received.wait(@mutex, remaining_time)
      end
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

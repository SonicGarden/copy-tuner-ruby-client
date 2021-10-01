class FakeClient
  def initialize
    @data = {}
    @uploaded = {}
    @uploads = 0
    @uploaded_key_access_logs = {}
    @key_access_log_uploads = 0
    @downloads = 0
    @mutex = Mutex.new
    @cond = ConditionVariable.new
    @go = false
  end

  attr_reader :uploaded, :uploads, :downloads, :uploaded_key_access_logs, :key_access_log_uploads
  attr_accessor :delay, :error

  def []=(key, value)
    @data[key] = value
  end

  def download
    wait_for_delay
    raise_error_if_present
    @downloads += 1
    yield @data.dup
    nil
  end

  def upload(data)
    wait_for_delay
    raise_error_if_present
    @uploaded.update(data)
    @uploads += 1
  end

  def upload_key_acess_log(data)
    wait_for_delay
    raise_error_if_present
    @uploaded_key_access_logs.update(data)
    @key_access_log_uploads += 1
  end

  def uploaded?
    @uploads > 0
  end

  def key_access_log_uploaded?
    @key_access_log_uploads > 0
  end

  def downloaded?
    @downloads > 0
  end

  def go
    @mutex.synchronize do
      @go = true
      @cond.signal
    end
  end

  private

  def wait_for_delay
    if delay
      @mutex.synchronize do
        @cond.wait(@mutex) until @go
      end
    end
  end

  def raise_error_if_present
    if error
      raise error
    end
  end
end


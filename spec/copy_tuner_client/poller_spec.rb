require 'spec_helper'

describe CopyTunerClient::Poller do
  let(:client) { FakeClient.new }
  let(:cache) { CopyTunerClient::Cache.new(client, logger: FakeLogger.new) }
  let!(:pollers) { [] }

  def polling_delay
    0.5
  end

  def build_poller(config = {})
    config[:logger] ||= FakeLogger.new
    config[:polling_delay] ||= polling_delay
    default_config = CopyTunerClient::Configuration.new.to_hash
    poller = CopyTunerClient::Poller.new(cache, default_config.update(config))
    pollers << poller
    poller
  end

  def wait_for_next_sync
    sleep(polling_delay * 3)
  end

  after do
    pollers.each(&:stop)
  end

  it 'polls after being started' do
    poller = build_poller
    poller.start

    client['test.key'] = 'value'
    wait_for_next_sync

    expect(cache['test.key']).to eq('value')
  end

  it "doesn't poll before being started" do
    build_poller
    client['test.key'] = 'value'

    wait_for_next_sync

    expect(cache['test.key']).to be_nil
  end

  it 'stops polling when stopped' do
    poller = build_poller

    poller.start
    poller.stop

    client['test.key'] = 'value'
    wait_for_next_sync

    expect(cache['test.key']).to be_nil
  end

  it 'stops polling with an invalid api key' do
    failure = 'server is napping'
    logger = FakeLogger.new

    allow(cache).to receive(:download).and_raise(CopyTunerClient::InvalidApiKey.new(failure))
    poller = build_poller(logger:)

    cache['upload.key'] = 'upload'
    poller.start
    wait_for_next_sync

    expect(logger).to have_entry(:error, failure)

    client['test.key'] = 'test value'
    wait_for_next_sync

    expect(cache['test.key']).to be_nil
  end

  it "logs an error if the background thread can't start" do
    allow(Thread).to receive(:new).and_return(nil)
    logger = FakeLogger.new

    build_poller(logger:).start

    expect(logger).to have_entry(:error, "Couldn't start poller thread")
  end

  it 'flushes the log when polling' do
    logger = FakeLogger.new
    allow(logger).to receive(:flush)

    build_poller(logger:).start

    wait_for_next_sync

    expect(logger).to have_received(:flush).at_least(:once)
  end

  describe '#stop' do
    it 'スレッドを停止したときは true を返す' do
      poller = build_poller
      poller.start

      expect(poller.stop).to be true
    end

    it 'スレッドが動いていないときは false を返す' do
      poller = build_poller

      expect(poller.stop).to be false
    end

    it 'スレッドが例外で終わっていても例外を再送出しない' do
      # stop は fork の直前にも呼ばれる。ここで join が poller の例外を再送出すると
      # アプリ側の fork まで巻き添えになる
      logger = FakeLogger.new
      allow(cache).to receive(:sync).and_raise('boom')
      poller = build_poller(logger:)
      poller.start
      sleep(polling_delay * 0.2)

      expect { poller.stop }.not_to raise_error
      expect(logger).to have_entry(:error, 'boom')
    end

    it 'start していないときに stop してもキューに :stop を残さない' do
      poller = build_poller
      poller.stop

      poller.start

      # 1 周目の sync だけでは「:stop がキューに残っている」状態と区別できないため、
      # 2 周目以降も同期が続くことを確かめる
      wait_for_next_sync
      client['test.key'] = 'value'
      wait_for_next_sync

      expect(cache['test.key']).to eq('value')
    end
  end

  describe '世代をまたいだコマンドの混入' do
    # :stop は pop されるまでキューに残る。前の世代のスレッド宛に積まれた :stop を
    # 次の世代のスレッドが拾うと、起動直後に自分を止めてしまう
    it 'スレッドが例外で死んだ後に stop → start してもポーリングが続く' do
      poller = build_poller
      allow(cache).to receive(:sync).and_raise('boom')
      poller.start
      sleep(polling_delay * 0.3) # スレッドが例外で終わるのを待つ

      allow(cache).to receive(:sync).and_call_original
      poller.stop
      poller.start

      wait_for_next_sync
      client['test.key'] = 'value'
      wait_for_next_sync

      expect(cache['test.key']).to eq('value')
    end

    it 'stop の直後に sync が例外で終わっても、次の start でポーリングが続く' do
      poller = build_poller
      # stop が :stop を積んだ後にスレッドが例外で終わる順序を作る。
      # sync に入ったところで stop を待たせ、:stop を積み終えてから例外にする
      syncing = Queue.new
      resume = Queue.new
      allow(cache).to receive(:sync) do
        syncing << true
        resume.pop
        raise 'boom'
      end

      poller.start
      syncing.pop # スレッドが sync に入った

      stopper = Thread.new { poller.stop }
      sleep(0.1) # :stop がキューに積まれるのを待つ
      resume << true # ここで sync が例外になり、:stop は消費されない
      stopper.join

      allow(cache).to receive(:sync).and_call_original
      poller.start

      wait_for_next_sync
      client['test.key'] = 'value'
      wait_for_next_sync

      expect(cache['test.key']).to eq('value')
    end

    it 'スレッドが例外で死んだ後の stop は false を返す' do
      poller = build_poller
      allow(cache).to receive(:sync).and_raise('boom')
      poller.start
      sleep(polling_delay * 0.3)

      expect(poller.stop).to be false
    end
  end

  describe '再開時の sync 間隔' do
    # 経過時間で判定するため、CI の負荷や GC で sleep が伸びても落ちないよう
    # 他のテストより長い間隔を使ってマージンを稼ぐ
    let(:slow_delay) { 2.0 }

    it '初回の start では待たずに sync する' do
      poller = build_poller(polling_delay: slow_delay)

      poller.start
      sleep(slow_delay * 0.2)

      expect(client.downloads).to eq(1)
    end

    it '停止直後に再開したときは前回 sync からの残り時間を待ってから sync する' do
      poller = build_poller(polling_delay: slow_delay)
      poller.start
      sleep(slow_delay * 0.2)
      poller.stop

      poller.start

      # 前回 sync から polling_delay 経つまでは sync しない
      sleep(slow_delay * 0.4)
      expect(client.downloads).to eq(1)

      # 残り時間が過ぎれば sync が再開する
      sleep(slow_delay * 0.8)
      expect(client.downloads).to eq(2)
    end
  end
end

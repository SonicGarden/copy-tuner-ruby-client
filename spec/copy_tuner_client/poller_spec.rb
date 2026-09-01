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
    config[:polling_delay] = polling_delay
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

  describe '再開時の sync 間隔' do
    it '初回の start では待たずに sync する' do
      poller = build_poller

      poller.start
      sleep(polling_delay * 0.2)

      expect(client.downloads).to eq(1)
    end

    it '停止直後に再開したときは前回 sync からの残り時間を待ってから sync する' do
      poller = build_poller
      poller.start
      sleep(polling_delay * 0.2)
      poller.stop

      poller.start

      # 前回 sync から polling_delay 経つまでは sync しない
      sleep(polling_delay * 0.4)
      expect(client.downloads).to eq(1)

      # 残り時間が過ぎれば sync が再開する
      sleep(polling_delay * 0.8)
      expect(client.downloads).to eq(2)
    end
  end
end

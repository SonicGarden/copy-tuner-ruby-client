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

  it 'start した後はポーリングする' do
    poller = build_poller
    poller.start

    client['test.key'] = 'value'
    wait_for_next_sync

    expect(cache['test.key']).to eq('value')
  end

  it 'start する前はポーリングしない' do
    build_poller
    client['test.key'] = 'value'

    wait_for_next_sync

    expect(cache['test.key']).to be_nil
  end

  it 'stop するとポーリングを停止する' do
    poller = build_poller

    poller.start
    poller.stop

    client['test.key'] = 'value'
    wait_for_next_sync

    expect(cache['test.key']).to be_nil
  end

  it '無効な API キーの場合はポーリングを停止する' do
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

  it 'バックグラウンドスレッドを起動できない場合はエラーをログに残す' do
    allow(Thread).to receive(:new).and_return(nil)
    logger = FakeLogger.new

    build_poller(logger:).start

    expect(logger).to have_entry(:error, "Couldn't start poller thread")
  end

  it 'ポーリング時にログを flush する' do
    logger = FakeLogger.new
    allow(logger).to receive(:flush)

    build_poller(logger:).start

    wait_for_next_sync

    expect(logger).to have_received(:flush).at_least(:once)
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

  describe 'fork をまたいだ場合' do
    # Thread.new を実行させると poller スレッドが後始末されずテストを跨いで残るため、
    # 分岐ロジックだけを見るためにダミーを返す
    let(:dummy_thread) { instance_double(Thread, join: nil) }

    before do
      allow(Thread).to receive(:new).and_return(dummy_thread)
    end

    it '別プロセスで start するとスレッドを張り直す' do
      poller = build_poller

      allow(Process).to receive(:pid).and_return(100)
      poller.start

      allow(Process).to receive(:pid).and_return(200)
      poller.start

      expect(Thread).to have_received(:new).twice
    end

    it '同じプロセスで二度 start してもスレッドは 1 本だけ' do
      poller = build_poller

      allow(Process).to receive(:pid).and_return(100)
      poller.start
      poller.start

      expect(Thread).to have_received(:new).once
    end
  end

  describe 'fork をまたいだ stop' do
    it '別プロセスで stop してもキューに :stop を残さないので次の start でポーリングが動く' do
      poller = build_poller

      # 親プロセス側の start ではスレッドを実際に動かさない（fork 後の子には引き継がれないため）
      allow(Thread).to receive(:new).and_return(instance_double(Thread, join: nil))
      allow(Process).to receive(:pid).and_return(100)
      poller.start

      # fork 後の子プロセスで stop → start する流れを再現する
      allow(Thread).to receive(:new).and_call_original
      allow(Process).to receive(:pid).and_call_original
      poller.stop
      poller.start

      # 1 周目の sync だけでは「:stop がキューに残っている」状態と区別できないため、
      # 2 周目以降も同期が続くことを確かめる
      wait_for_next_sync
      client['test.key'] = 'value'
      wait_for_next_sync

      expect(cache['test.key']).to eq('value')
    end

    it '別プロセスの stop では他プロセスのスレッドを join しない' do
      poller = build_poller

      other_thread = instance_double(Thread, join: nil)
      allow(Thread).to receive(:new).and_return(other_thread)
      allow(Process).to receive(:pid).and_return(100)
      poller.start

      allow(Process).to receive(:pid).and_return(200)
      poller.stop

      expect(other_thread).not_to have_received(:join)
    end
  end
end

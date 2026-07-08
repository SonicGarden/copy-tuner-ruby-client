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
end

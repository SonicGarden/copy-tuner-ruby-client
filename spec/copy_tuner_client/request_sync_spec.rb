require 'spec_helper'

describe CopyTunerClient::RequestSync do
  let(:poller) { {} }
  let(:cache) { {} }
  let(:response) { 'response' }
  let(:app) { double('app', call: response) }

  before do
    allow(cache).to receive_messages(flush: nil, download: nil)
    allow(poller).to receive(:start_sync).and_return(nil)
  end

  context 'interval が 0 の場合' do
    subject(:request_sync) { described_class.new(app, poller:, cache:, interval: 0) }

    let(:env) { 'env' }

    it 'invokes the upstream app' do
      result = request_sync.call(env)
      expect(app).to have_received(:call).with(env)
      expect(result).to eq(response)
    end
  end

  context 'when serving assets' do
    subject(:request_sync) { described_class.new(app, poller:, cache:, interval: 0) }

    let(:env) do
      { 'PATH_INFO' => '/assets/choper.png' }
    end

    it "don't start sync" do
      request_sync.call(env)
      request_sync.call(env)

      expect(cache).to have_received(:download).once
      expect(poller).not_to have_received(:start_sync)
    end
  end

  context 'interval が 10 の場合' do
    subject(:request_sync) { described_class.new(app, poller:, cache:, interval: 10) }

    let(:env) { 'env' }

    context 'first request' do
      it 'download' do
        request_sync.call(env)
        expect(cache).to have_received(:download).once
      end
    end

    context 'in interval request' do
      it 'does not start sync for the second time' do
        request_sync.call(env)
        request_sync.call(env)

        expect(cache).to have_received(:download).once
        expect(poller).not_to have_received(:start_sync)
      end
    end

    context 'over interval request' do
      it 'start sync for the second time' do
        request_sync.call(env)

        request_sync.last_synced = Time.now - 60
        request_sync.call(env)

        expect(cache).to have_received(:download).once
        expect(poller).to have_received(:start_sync).once
      end
    end
  end
end

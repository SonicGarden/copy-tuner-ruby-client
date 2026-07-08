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
      expect(app).to receive(:call).with(env)
      result = request_sync.call(env)
      expect(result).to eq(response)
    end
  end

  context 'when serving assets' do
    subject(:request_sync) { described_class.new(app, poller:, cache:, interval: 0) }

    let(:env) do
      { 'PATH_INFO' => '/assets/choper.png' }
    end

    it "don't start sync" do
      expect(cache).to receive(:download).once
      request_sync.call(env)
      expect(poller).not_to receive(:start_sync)
      request_sync.call(env)
    end
  end

  context 'interval が 10 の場合' do
    subject(:request_sync) { described_class.new(app, poller:, cache:, interval: 10) }

    let(:env) { 'env' }

    context 'first request' do
      it 'download' do
        expect(cache).to receive(:download).once
        request_sync.call(env)
      end
    end

    context 'in interval request' do
      it 'does not start sync for the second time' do
        expect(cache).to receive(:download).once
        request_sync.call(env)

        expect(poller).not_to receive(:start_sync)
        request_sync.call(env)
      end
    end

    context 'over interval request' do
      it 'start sync for the second time' do
        expect(cache).to receive(:download).once
        request_sync.call(env)

        expect(poller).to receive(:start_sync).once
        request_sync.last_synced = Time.now - 60
        request_sync.call(env)
      end
    end
  end
end

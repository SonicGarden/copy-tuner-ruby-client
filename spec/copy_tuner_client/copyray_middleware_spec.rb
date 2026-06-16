require 'spec_helper'
require 'copy_tuner_client/copyray_middleware'
require 'copy_tuner_client/copyray/marker'
require 'copy_tuner_client/translation_log'

describe CopyTunerClient::CopyrayMiddleware do
  def marker(key)
    CopyTunerClient::Copyray::Marker.encode(key)
  end

  let(:headers) { { 'Content-Type' => 'text/html' } }
  let(:app) { ->(_env) { [status, headers, [body]] } }
  let(:status) { 200 }

  subject(:middleware) { described_class.new(app) }

  before do
    CopyTunerClient.configure do |configuration|
      configuration.client = FakeClient.new
    end
    # NOTE: CSS/JS 挿入は Rails の ActionController::Base.helpers に依存するため、
    # Rewriter の効果だけを検証できるよう no-op にスタブする。
    allow(middleware).to receive(:append_css) { |html, _| html }
    allow(middleware).to receive(:append_js) { |html, _| html }
  end

  context 'html response with a marker token' do
    let(:body) { "<html><body><p>#{marker('a.b')}Hello</p></body></html>" }

    it 'rewrites the marker into a data-copyray-key attribute and removes the token' do
      _status, _headers, response = middleware.call({})
      result = response.join

      expect(result).to include('data-copyray-key="a.b"')
      expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
    end

    it 'recomputes Content-Length from the rewritten body' do
      _status, out_headers, response = middleware.call({})
      expect(out_headers['Content-Length']).to eq response.join.bytesize.to_s
    end
  end

  context 'non-html response' do
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:body) { "{\"x\":\"#{marker('a.b')}\"}" }

    it 'passes through without rewriting' do
      _status, _headers, response = middleware.call({})
      expect(response.join).to eq body
    end
  end
end

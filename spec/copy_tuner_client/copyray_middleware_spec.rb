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

  context 'マーカートークンを含む HTML レスポンスのとき' do
    let(:body) { "<html><body><p>#{marker('a.b')}Hello</p></body></html>" }

    it 'マーカーを data-copyray-key 属性に書き換え、トークンを除去する' do
      _status, _headers, response = middleware.call({})
      result = response.join

      expect(result).to include('data-copyray-key="a.b"')
      expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
    end

    it '書き換え後のボディから Content-Length を再計算する' do
      _status, out_headers, response = middleware.call({})
      expect(out_headers['Content-Length']).to eq response.join.bytesize.to_s
    end
  end

  context 'HTML 以外のレスポンスのとき' do
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:body) { "{\"x\":\"#{marker('a.b')}\"}" }

    it '書き換えずにそのまま通過させる' do
      _status, _headers, response = middleware.call({})
      expect(response.join).to eq body
    end
  end
end

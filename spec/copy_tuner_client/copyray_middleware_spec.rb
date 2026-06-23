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
    allow(middleware).to receive(:append_js) { |html, *| html }
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

  describe '#append_js' do
    # NOTE: append_js は private かつ Rails の view ヘルパー（javascript_tag 等）に依存する。
    # トップレベルの no-op スタブを外して実体を呼び、ヘルパーは渡された script 本文をそのまま
    # 返す最小フェイクに差し替えて、window.CopyTuner に keysSkipped が埋まることだけ検証する。
    subject(:script) { middleware.__send__(:append_js, '<html><body></body></html>', nil, skipped: skipped) }

    let(:fake_helpers) do
      Class.new {
        def javascript_tag(content, **_opts) = content
        def javascript_include_tag(*, **) = ''
      }.new
    end

    before do
      allow(middleware).to receive(:append_js).and_call_original
      allow(middleware).to receive(:helpers).and_return(fake_helpers)
    end

    context 'skipped が true のとき' do
      let(:skipped) { true }

      it 'window.CopyTuner に keysSkipped: true を出力する' do
        expect(script).to include('keysSkipped: true')
      end
    end

    context 'skipped が false のとき' do
      let(:skipped) { false }

      it 'window.CopyTuner に keysSkipped: false を出力する' do
        expect(script).to include('keysSkipped: false')
      end
    end
  end
end

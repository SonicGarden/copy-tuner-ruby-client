require 'spec_helper'
require 'copy_tuner_client/copyray_middleware'
require 'copy_tuner_client/copyray'
require 'copy_tuner_client/copyray/marker'
require 'copy_tuner_client/translation_log'

# Warden::Manager の catch(:warden) と failure app 呼び出しだけを模した fake（warden gem に依存しないため）
class FakeWarden
  def initialize(app, failure_app)
    @app = app
    @failure_app = failure_app
  end

  def call(env)
    result = catch(:warden) { @app.call(env) }
    result.is_a?(Array) ? result : @failure_app.call(env)
  end
end

# NOTE: CopyrayMiddleware 単体ではなく、Warden 相当の fake との組み合わせ位置を検証するため
# describe の第一引数はクラスではなく説明文にしている
describe 'throw :warden と CopyrayMiddleware の位置関係' do # rubocop:disable RSpec/DescribeClass
  def marker(key)
    CopyTunerClient::Copyray::Marker.encode(key)
  end

  # NOTE: authenticate_user! 失敗を模す。throw :warden するとこの @app.call(env) は正常リターンせず、
  # CopyrayMiddleware が内側にあると Rewriter.rewrite が実行されない。
  let(:throwing_app) { ->(_env) { throw :warden } }
  let(:failure_status) { 200 }
  let(:failure_app) do
    ->(_env) do
      [failure_status, { 'Content-Type' => 'text/html' }, [failure_body]]
    end
  end
  let(:failure_body) { "<html><body><p>#{marker('devise.failure.unauthenticated')}Please sign in</p></body></html>" }

  before do
    CopyTunerClient.configure do |configuration|
      configuration.project_id = 1
      configuration.client = FakeClient.new
    end
  end

  # NOTE: append_js は Rails の ActionController::Base.helpers に依存するため、
  # copyray_middleware_spec.rb と同じ手法で no-op スタブに差し替え、Rewriter の効果だけを見る。
  def stub_append_js(middleware)
    allow(middleware).to receive(:append_js) { |html, *| html }
  end

  context '内側構成（CopyrayMiddleware が Warden より内側）のとき' do
    it 'マーカー ⟦CT: がレスポンスに残る（不具合の記録）' do
      copyray = CopyTunerClient::CopyrayMiddleware.new(throwing_app)
      stub_append_js(copyray)
      warden = FakeWarden.new(copyray, failure_app)

      _status, _headers, response = warden.call({})
      result = response.join

      expect(result).to match(CopyTunerClient::Copyray::Marker::SCAN_REGEXP)
    end
  end

  context '外側構成（CopyrayMiddleware が Warden より外側）のとき' do
    it 'マーカーが消え data-copyray-key に変換される' do
      warden = FakeWarden.new(throwing_app, failure_app)
      copyray = CopyTunerClient::CopyrayMiddleware.new(warden)
      stub_append_js(copyray)

      _status, _headers, response = copyray.call({})
      result = response.join

      expect(result).to include('data-copyray-key="devise.failure.unauthenticated"')
      expect(result).not_to match(CopyTunerClient::Copyray::Marker::SCAN_REGEXP)
    end

    context 'failure app が 422 を返すとき（Devise.responder.error_status = :unprocessable_entity 相当）' do
      let(:unprocessable_failure_app) do
        ->(_env) { [422, { 'Content-Type' => 'text/html' }, [failure_body]] }
      end

      it 'マーカーが消え data-copyray-key に変換される' do
        warden = FakeWarden.new(throwing_app, unprocessable_failure_app)
        copyray = CopyTunerClient::CopyrayMiddleware.new(warden)
        stub_append_js(copyray)

        _status, _headers, response = copyray.call({})
        result = response.join

        expect(result).to include('data-copyray-key="devise.failure.unauthenticated"')
        expect(result).not_to match(CopyTunerClient::Copyray::Marker::SCAN_REGEXP)
      end
    end
  end
end

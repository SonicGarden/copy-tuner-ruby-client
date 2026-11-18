require 'spec_helper'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::Copyray do
  # NOTE: request.format で描画フォーマットを判定するため、format を差し替えられる
  # 最小のフェイク request / controller を用意する。mailer 判定は controller の型で行う。
  let(:format_class) do
    Struct.new(:type) do
      def html?
        type == :html
      end
    end
  end
  let(:request_class) { Struct.new(:format, :env) }
  let(:controller_class) { Struct.new(:request) }

  # NOTE: CopyrayMiddleware を通るリクエストを再現するため、フラグ付きの env を持つ request を作る。
  def injectable_request(format = :html)
    request_class.new(format_class.new(format), { described_class::ENV_KEY => true })
  end

  describe '.injectable?' do
    it 'request.format が html のとき true を返す' do
      expect(described_class.injectable?(controller_class.new(injectable_request))).to be true
    end

    %i[json text csv pdf].each do |format|
      it "request.format が :#{format} のとき false を返す" do
        expect(described_class.injectable?(controller_class.new(injectable_request(format)))).to be false
      end
    end

    it 'disable_copyray_comment_injection が有効なとき false を返す' do
      CopyTunerClient.configuration.disable_copyray_comment_injection = true
      expect(described_class.injectable?(controller_class.new(injectable_request))).to be false
    end

    it 'format が html でも env にフラグが無ければ false を返す' do
      controller = controller_class.new(request_class.new(format_class.new(:html), {}))
      expect(described_class.injectable?(controller)).to be false
    end

    it 'request.env が nil でも落ちずに false を返す' do
      controller = controller_class.new(request_class.new(format_class.new(:html), nil))
      expect(described_class.injectable?(controller)).to be false
    end

    it 'mailer から描画されたとき false を返す' do
      stub_const('ActionMailer::Base', Class.new)
      expect(described_class.injectable?(ActionMailer::Base.new)).to be false
    end

    it 'controller が nil のとき false を返す' do
      expect(described_class.injectable?(nil)).to be false
    end

    it 'controller が request を持たないとき false を返す' do
      expect(described_class.injectable?(controller_class.new(nil))).to be false
    end

    it 'ActionMailer が未ロードでも落ちない' do
      hide_const('ActionMailer::Base') if defined?(ActionMailer::Base)
      expect { described_class.injectable?(controller_class.new(injectable_request)) }.not_to raise_error
    end
  end

  describe '.augment_template' do
    subject(:augmented) { described_class.augment_template(source, key) }

    let(:key) { 'en.test.key' }

    before do
      CopyTunerClient.configure do |configuration|
        configuration.project_id = 1
        configuration.client = FakeClient.new
      end
    end

    context 'when the source is html_safe (e.g. _html key)' do
      let(:source) { FakeHtmlSafeString.new('<b>Hello</b>').html_safe }

      it 'keeps the html_safe flag so the translation is not re-escaped' do
        expect(augmented).to be_html_safe
      end

      it 'prepends the visible marker token without escaping' do
        expect(augmented).to eq '⟦CT:en.test.key⟧<b>Hello</b>'
      end
    end

    context 'when the source is plain text (not html_safe)' do
      let(:source) { FakeHtmlSafeString.new('Hello & <World>') }

      it 'prepends the marker but keeps the source non html_safe so ActionView still escapes the body' do
        expect(augmented).to eq '⟦CT:en.test.key⟧Hello & <World>'
        expect(augmented).not_to be_html_safe
      end
    end

    context 'when the key matches local_first_key_regexp' do
      let(:local_first_key) { 'views.foo' }

      before { CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./ }

      it 'does not inject the marker into a plain source' do
        expect(described_class.augment_template('Hello', local_first_key)).to eq 'Hello'
      end

      it 'does not inject the marker into an html_safe source' do
        expect(described_class.augment_template('Hello'.html_safe, local_first_key)).to eq 'Hello'
      end
    end
  end
end

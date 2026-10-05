require 'spec_helper'
require 'copy_tuner_client/helper_extension'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::HelperExtension do
  include DefinesConstants

  # NOTE: request.format で描画フォーマットを判定するため、format を差し替えられる
  # 最小のフェイク request / controller を用意する。mailer 判定は controller の型で行う。
  def format_class
    @format_class ||=
      Struct.new(:type) do
        def html?
          type == :html
        end
      end
  end

  def request_class
    @request_class ||= Struct.new(:format, :env)
  end

  # NOTE: CopyrayMiddleware を通るリクエストを再現するため、フラグ付きの env を持つ request を作る。
  def injectable_request(format = :html)
    request_class.new(format_class.new(format), { CopyTunerClient::Copyray::ENV_KEY => true })
  end

  def controller_class
    @controller_class ||= Struct.new(:request)
  end

  # NOTE: hook_translation_helper は渡されたモジュール自体を破壊的に変更する（alias_method 等）ため、
  # view に include するモジュールと hook_translation_helper に渡すモジュールは同一オブジェクトである必要がある。
  def keyword_arguments_helper
    @keyword_arguments_helper ||=
      Module.new do
        attr_accessor :controller

        # NOTE: ActionView の TranslationHelper を模し、.html/_html キーのみ html_safe な訳文を返す。
        # マーカーは平文・html_safe どちらにも注入されるが、html_safe フラグの引き継ぎを検証できるよう両方返し分ける。
        define_method(:translate) do |key, **options|
          source = "Hello, #{options[:name]}"
          key.to_s.end_with?('.html', '_html') ? source.html_safe : source
        end
      end
  end

  # NOTE: 実 HTML 描画では controller が存在し request.format が html になるため、
  # デフォルトはそれを再現した controller を持たせておく。
  let(:view) do
    Class.new.include(keyword_arguments_helper).new.tap do |v|
      v.controller = controller_class.new(injectable_request)
    end
  end

  before do
    # NOTE: helper_extension が参照する CopyTunerClient::Rails は engine への依存があり
    # 単体 spec では require できず、controller_of_rails_engine? も ::Rails::Engine への
    # 依存があり単体 spec では評価できないため、この spec の関心（注入ガード）に絞って
    # 常に false を返すフェイクモジュールに差し替える。
    fake_rails_module = Module.new { def self.controller_of_rails_engine?(_controller) = false }
    define_constant('CopyTunerClient::Rails', fake_rails_module)
    described_class.hook_translation_helper(keyword_arguments_helper, middleware_enabled: true)
  end

  it 'works with keyword argument method' do
    expect(view.translate('some.key_html', name: 'World')).to eq '⟦CT:some.key_html⟧Hello, World'
  end

  it 'injects the marker into a plain (non html_safe) translation, keeping it non html_safe' do
    result = view.translate('some.key', name: 'World')
    expect(result).to eq '⟦CT:some.key⟧Hello, World'
    expect(result).not_to be_html_safe
  end

  it 'keeps the html_safe flag for an _html key so the body is not re-escaped' do
    expect(view.translate('some.key_html', name: 'World')).to be_html_safe
  end

  it 'does not inject the overlay marker for a local_first key' do
    CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./
    expect(view.translate('views.foo', name: 'World')).to eq 'Hello, World'
  end

  context 'injection guard by rendering context' do
    it 'injects the marker when request.format is :html' do
      expect(view.translate('some.key', name: 'World')).to eq '⟦CT:some.key⟧Hello, World'
    end

    %i[json text csv pdf].each do |format|
      it "does not inject the marker when request.format is :#{format}" do
        view.controller = controller_class.new(injectable_request(format))
        expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
      end
    end

    it 'format が html でも env にフラグが無ければ注入しない' do
      view.controller = controller_class.new(request_class.new(format_class.new(:html), {}))
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'request.env が nil でも落ちずに注入しない' do
      view.controller = controller_class.new(request_class.new(format_class.new(:html), nil))
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end
  end

  context 'injection guard by controller' do
    it 'does not inject the marker when rendered by a mailer' do
      stub_const('ActionMailer::Base', Class.new)
      view.controller = ActionMailer::Base.new
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not inject the marker when controller is nil' do
      view.controller = nil
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not inject the marker when the controller has no request' do
      view.controller = controller_class.new(nil)
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not raise when ActionMailer is not loaded' do
      hide_const('ActionMailer::Base') if defined?(ActionMailer::Base)
      view.controller = controller_class.new(injectable_request)
      expect { view.translate('some.key', name: 'World') }.not_to raise_error
    end
  end

  # NOTE: マーカー注入を抑止する非 HTML 経路でも、default 引数による初期値登録（I18n.t 呼び出し）は
  # 維持されなければならない。注入ガードが初期値登録まで巻き添えで止めていないことを保証する。
  context 'default value registration' do
    it 'registers the default value even when the marker is not injected' do
      view.controller = controller_class.new(injectable_request(:json))
      allow(I18n).to receive(:t)
      view.translate('some.key', name: 'World', default: 'Default')
      expect(I18n).to have_received(:t).with('some.key', hash_including(default: 'Default'))
    end
  end

  describe '.hook_render_to_string' do
    # NOTE: ActionController::Base を読み込まずに検証するため、super 呼び出し時の env の状態を
    # 記録するだけの最小の基底クラスに prepend する。
    let(:base_class) do
      Class.new do
        attr_reader :request, :recorded

        def initialize(request)
          @request = request
          @recorded = []
        end

        def render_to_string(*_args, raise_error: false, nested: false)
          record_flag
          if nested
            render_to_string
            record_flag
          end
          raise 'boom' if raise_error

          'rendered'
        end

        def record_flag
          @recorded << request&.env&.key?(CopyTunerClient::Copyray::ENV_KEY)
        end
      end
    end
    let(:env) { { CopyTunerClient::Copyray::ENV_KEY => true } }
    let(:controller) { base_class.new(request_class.new(format_class.new(:html), env)) }

    context 'middleware_enabled が true のとき' do
      before { described_class.hook_render_to_string(base_class, middleware_enabled: true) }

      it '実行中は env からフラグが外れる' do
        controller.render_to_string
        expect(controller.recorded).to eq [false]
      end

      it '元の戻り値を返す' do
        expect(controller.render_to_string).to eq 'rendered'
      end

      it '終了後はフラグが復元される' do
        controller.render_to_string
        expect(env[CopyTunerClient::Copyray::ENV_KEY]).to be true
      end

      it '例外が起きてもフラグが復元される' do
        expect { controller.render_to_string(raise_error: true) }.to raise_error('boom')
        expect(env[CopyTunerClient::Copyray::ENV_KEY]).to be true
      end

      it '入れ子でも外側の終了時まで外れたまま' do
        controller.render_to_string(nested: true)
        expect(controller.recorded).to eq [false, false, false]
        expect(env[CopyTunerClient::Copyray::ENV_KEY]).to be true
      end

      it '元々フラグが無い env にはフラグを足さない' do
        env.clear
        controller.render_to_string
        expect(env).not_to have_key(CopyTunerClient::Copyray::ENV_KEY)
      end

      it 'request が nil でも落ちない' do
        controller = base_class.new(nil)
        expect(controller.render_to_string).to eq 'rendered'
      end
    end

    context 'middleware_enabled が false のとき' do
      before { described_class.hook_render_to_string(base_class, middleware_enabled: false) }

      it 'フックせず実行中もフラグが残る' do
        controller.render_to_string
        expect(controller.recorded).to eq [true]
      end
    end
  end
end

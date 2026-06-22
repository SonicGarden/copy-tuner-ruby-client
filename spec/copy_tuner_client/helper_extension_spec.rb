require 'spec_helper'
require 'copy_tuner_client/helper_extension'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::HelperExtension do
  # NOTE: helper_extension が参照する CopyTunerClient::Rails は engine への依存があり
  # 単体 spec では require できないため、メソッドをスタブできる最小の入れ物だけ用意する。
  module CopyTunerClient
    module Rails
      def self.controller_of_rails_engine?(_controller)
        false
      end
    end
  end

  # NOTE: request.format で描画フォーマットを判定するため、format を差し替えられる
  # 最小のフェイク request / controller を用意する。mailer 判定は controller の型で行う。
  Format = Struct.new(:type) do
    def html?
      type == :html
    end
  end
  Request = Struct.new(:format)
  Controller = Struct.new(:request)

  module KeywordArgumentsHelper
    attr_writer :controller

    # NOTE: ActionView の TranslationHelper を模し、.html/_html キーのみ html_safe な訳文を返す。
    # マーカーは平文・html_safe どちらにも注入されるが、html_safe フラグの引き継ぎを検証できるよう両方返し分ける。
    def translate(key, **options)
      source = "Hello, #{options[:name]}"
      key.to_s.end_with?('.html', '_html') ? source.html_safe : source
    end

    def controller
      return @controller if defined?(@controller)

      # NOTE: 実 HTML 描画では controller が存在し request.format が html になるため、
      # デフォルトはそれを再現した controller。
      @controller = Controller.new(Request.new(Format.new(:html)))
    end
  end

  class KeywordArgumentsView
    include KeywordArgumentsHelper
  end

  CopyTunerClient::HelperExtension.hook_translation_helper(KeywordArgumentsHelper, middleware_enabled: true)

  let(:view) { KeywordArgumentsView.new }

  before do
    # NOTE: controller_of_rails_engine? は ::Rails::Engine への依存があり単体 spec では評価できないため、
    # この spec の関心（注入ガード）に絞って常に false を返すようスタブする。
    allow(CopyTunerClient::Rails).to receive(:controller_of_rails_engine?).and_return(false)
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
        view.controller = Controller.new(Request.new(Format.new(format)))
        expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
      end
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
      view.controller = Controller.new(nil)
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not raise when ActionMailer is not loaded' do
      hide_const('ActionMailer::Base') if defined?(ActionMailer::Base)
      view.controller = Controller.new(Request.new(Format.new(:html)))
      expect { view.translate('some.key', name: 'World') }.not_to raise_error
    end
  end

  # NOTE: マーカー注入を抑止する非 HTML 経路でも、default 引数による初期値登録（I18n.t 呼び出し）は
  # 維持されなければならない。注入ガードが初期値登録まで巻き添えで止めていないことを保証する。
  context 'default value registration' do
    it 'registers the default value even when the marker is not injected' do
      view.controller = Controller.new(Request.new(Format.new(:json)))
      expect(I18n).to receive(:t).with('some.key', hash_including(default: 'Default'))
      view.translate('some.key', name: 'World', default: 'Default')
    end
  end
end

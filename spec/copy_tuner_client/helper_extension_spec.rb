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

  # NOTE: format / controller を差し替えられる最小のフェイクビュー。
  # @current_template.format と lookup_context.formats.first で描画フォーマットを、
  # controller で mailer 判定を再現する。
  Template = Struct.new(:format)
  LookupContext = Struct.new(:formats)

  module KeywordArgumentsHelper
    attr_writer :current_template, :lookup_context, :controller

    # NOTE: ActionView の TranslationHelper を模し、.html/_html キーのみ html_safe な訳文を返す。
    # マーカーは平文・html_safe どちらにも注入されるが、html_safe フラグの引き継ぎを検証できるよう両方返し分ける。
    def translate(key, **options)
      source = "Hello, #{options[:name]}"
      key.to_s.end_with?('.html', '_html') ? source.html_safe : source
    end

    def lookup_context
      @lookup_context ||= LookupContext.new([:html])
    end

    def controller
      return @controller if defined?(@controller)

      # NOTE: 実 HTML 描画では controller が存在するため、デフォルトは非 nil の素のオブジェクト。
      @controller = Object.new
    end
  end

  class KeywordArgumentsView
    include KeywordArgumentsHelper
  end

  CopyTunerClient::HelperExtension.hook_translation_helper(KeywordArgumentsHelper, middleware_enabled: true)

  let(:view) { KeywordArgumentsView.new }

  before do
    view.current_template = Template.new(:html)
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
    it 'injects the marker when the template format is :html' do
      expect(view.translate('some.key', name: 'World')).to eq '⟦CT:some.key⟧Hello, World'
    end

    it 'falls back to lookup_context.formats.first when @current_template is nil' do
      view.current_template = nil
      view.lookup_context = LookupContext.new([:html])
      expect(view.translate('some.key', name: 'World')).to eq '⟦CT:some.key⟧Hello, World'
    end

    %i[json text csv pdf].each do |format|
      it "does not inject the marker when the template format is :#{format}" do
        view.current_template = Template.new(format)
        expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
      end
    end

    it 'does not inject the marker when rendered by a mailer' do
      stub_const('ActionMailer::Base', Class.new)
      view.current_template = Template.new(:html)
      view.controller = ActionMailer::Base.new
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not inject the marker when controller is nil' do
      view.current_template = Template.new(:html)
      view.controller = nil
      expect(view.translate('some.key', name: 'World')).to eq 'Hello, World'
    end

    it 'does not raise when ActionMailer is not loaded' do
      hide_const('ActionMailer::Base') if defined?(ActionMailer::Base)
      view.current_template = Template.new(:html)
      view.controller = Object.new
      expect { view.translate('some.key_html', name: 'World') }.not_to raise_error
    end
  end

  context 'tt（非推奨エイリアス）' do
    let(:deprecator) { instance_double(ActiveSupport::Deprecation, warn: nil) }

    before { allow(ActiveSupport::Deprecation).to receive(:new).and_return(deprecator) }

    it '呼び出すたびに非推奨警告を出す' do
      expect(deprecator).to receive(:warn).with(/tt is deprecated/)
      view.tt('some.key', name: 'World')
    end

    it 'マーカー注入版（t 相当）の結果を返す' do
      expect(view.tt('some.key', name: 'World')).to eq '⟦CT:some.key⟧Hello, World'
    end
  end

  # NOTE: マーカー注入を抑止する非 HTML 経路でも、default 引数による初期値登録（I18n.t 呼び出し）は
  # 維持されなければならない。注入ガードが初期値登録まで巻き添えで止めていないことを保証する。
  context 'default value registration' do
    it 'registers the default value even when the marker is not injected' do
      view.current_template = Template.new(:json)
      expect(I18n).to receive(:t).with('some.key', hash_including(default: 'Default'))
      view.translate('some.key', name: 'World', default: 'Default')
    end
  end
end

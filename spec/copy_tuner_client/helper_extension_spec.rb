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

    def translate(key, **options)
      "Hello, #{options[:name]}"
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
    expect(view.translate('some.key', name: 'World')).to eq '<!--COPYRAY some.key-->Hello, World'
  end

  it 'does not inject the overlay marker for a local_first key' do
    CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./
    expect(view.translate('views.foo', name: 'World')).to eq 'Hello, World'
  end

  context 'injection guard by rendering context' do
    it 'injects the marker when the template format is :html' do
      view.current_template = Template.new(:html)
      expect(view.translate('some.key', name: 'World')).to eq '<!--COPYRAY some.key-->Hello, World'
    end

    it 'falls back to lookup_context.formats.first when @current_template is nil' do
      view.current_template = nil
      view.lookup_context = LookupContext.new([:html])
      expect(view.translate('some.key', name: 'World')).to eq '<!--COPYRAY some.key-->Hello, World'
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
      expect { view.translate('some.key', name: 'World') }.not_to raise_error
    end
  end
end

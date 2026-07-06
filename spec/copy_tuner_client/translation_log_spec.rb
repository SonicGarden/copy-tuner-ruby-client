require 'spec_helper'
require 'copy_tuner_client/translation_log'

describe CopyTunerClient::TranslationLog do
  before { described_class.clear }

  describe '.add' do
    context '初期化済みの場合' do
      it 'キーを記録すること' do
        described_class.add('views.foo', 'Hello')
        expect(described_class.translations).to eq('views.foo' => 'Hello')
      end

      it '既存のキーを上書きしないこと' do
        described_class.add('views.foo', 'Hello')
        described_class.add('views.foo', 'World')
        expect(described_class.translations['views.foo']).to eq 'Hello'
      end

      context 'キーが local_first_key_regexp にマッチする場合' do
        before { CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./ }

        it 'マッチしたキーを記録しないこと' do
          described_class.add('views.foo', 'Hello')
          expect(described_class.translations).to be_empty
        end

        it 'マッチしないキーは記録すること' do
          described_class.add('messages.greeting', 'Hi')
          expect(described_class.translations).to eq('messages.greeting' => 'Hi')
        end
      end

      context 'local_first_key_regexp が未設定の場合' do
        it '全てのキーを記録すること' do
          described_class.add('views.foo', 'Hello')
          expect(described_class.translations).to eq('views.foo' => 'Hello')
        end
      end
    end

    context '未初期化の場合' do
      before { Thread.current[:translations] = nil }

      it 'キーを無視すること' do
        described_class.add('views.foo', 'Hello')
        expect(described_class.initialized?).to be false
      end
    end
  end

  describe '.install_hook' do
    # フック導入前後で I18n の特異クラスを復元し、他のテストへの副作用を防ぐ
    around do |example|
      original_singleton_methods = I18n.singleton_class.instance_methods(false)
      example.run
      (I18n.singleton_class.instance_methods(false) - original_singleton_methods).each do |method_name|
        I18n.singleton_class.__send__(:remove_method, method_name)
      end
    end

    context 'ミドルウェアが有効な場合' do
      before { allow(CopyTunerClient.configuration).to receive(:enable_middleware?).and_return(true) }

      it 'エラーを発生させずに I18n.translate をフックすること' do
        expect { described_class.install_hook }.not_to raise_error
        expect(I18n.translate(:hello, default: 'Hello')).to eq 'Hello'
        expect(described_class.translations).to have_key('hello')
      end
    end
  end
end

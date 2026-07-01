require 'spec_helper'
require 'copy_tuner_client/translation_log'

describe CopyTunerClient::TranslationLog do
  before { described_class.clear }

  describe '.add' do
    context 'when initialized' do
      it 'records the key' do
        described_class.add('views.foo', 'Hello')
        expect(described_class.translations).to eq('views.foo' => 'Hello')
      end

      it 'does not overwrite an existing key' do
        described_class.add('views.foo', 'Hello')
        described_class.add('views.foo', 'World')
        expect(described_class.translations['views.foo']).to eq 'Hello'
      end

      context 'when the key matches local_first_key_regexp' do
        before { CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./ }

        it 'does not record the matching key' do
          described_class.add('views.foo', 'Hello')
          expect(described_class.translations).to be_empty
        end

        it 'records keys that do not match' do
          described_class.add('messages.greeting', 'Hi')
          expect(described_class.translations).to eq('messages.greeting' => 'Hi')
        end
      end

      context 'when local_first_key_regexp is not set' do
        it 'records all keys' do
          described_class.add('views.foo', 'Hello')
          expect(described_class.translations).to eq('views.foo' => 'Hello')
        end
      end
    end

    context 'when not initialized' do
      before { Thread.current[:translations] = nil }

      it 'ignores the key' do
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

    context 'when middleware is enabled' do
      before { allow(CopyTunerClient.configuration).to receive(:enable_middleware?).and_return(true) }

      it 'hooks I18n.translate without raising an error' do
        expect { described_class.install_hook }.not_to raise_error
        expect(I18n.translate(:hello, default: 'Hello')).to eq 'Hello'
        expect(described_class.translations).to have_key('hello')
      end
    end
  end
end

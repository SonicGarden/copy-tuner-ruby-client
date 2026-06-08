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
end

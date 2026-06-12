require 'spec_helper'
require 'copy_tuner_client/subliminal'

describe CopyTunerClient::Subliminal do
  ZWNJ = "‌".freeze # bit 0
  ZWJ  = "‍".freeze # bit 1

  describe '.encode' do
    it 'returns a string composed only of the two invisible characters' do
      encoded = described_class.encode('en.test.key')
      expect(encoded.chars.uniq.sort).to eq [ZWNJ, ZWJ].sort
    end

    it 'emits 9 invisible characters per UTF-8 byte' do
      key = 'en.test.key'
      expect(described_class.encode(key).length).to eq key.bytesize * 9
    end

    it 'emits 9 invisible characters per UTF-8 byte for multibyte text' do
      key = 'ja.こんにちは'
      expect(described_class.encode(key).length).to eq key.bytesize * 9
    end
  end

  describe 'round trip (.decode of .encode)' do
    it 'restores ASCII text' do
      text = 'views.home.index.message'
      expect(described_class.decode(described_class.encode(text))).to eq text
    end

    it 'restores multibyte text' do
      text = 'こんにちは'
      expect(described_class.decode(described_class.encode(text))).to eq text
    end
  end

  describe '.remove' do
    it 'strips the invisible marker and leaves the visible text' do
      marked = described_class.encode('en.test.key') + 'Hello'
      expect(described_class.remove(marked)).to eq 'Hello'
    end

    it 'returns non-string values unchanged' do
      expect(described_class.remove(123)).to eq 123
      expect(described_class.remove(nil)).to be_nil
    end

    it 'leaves text without markers untouched' do
      expect(described_class.remove('Hello')).to eq 'Hello'
    end
  end
end

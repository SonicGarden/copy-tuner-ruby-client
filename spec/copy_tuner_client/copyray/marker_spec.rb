require 'spec_helper'
require 'copy_tuner_client/copyray/marker'

describe CopyTunerClient::Copyray::Marker do
  describe '.encode' do
    it 'wraps the key with the visible token delimiters' do
      expect(described_class.encode('views.home.index.message')).to eq '⟦CT:views.home.index.message⟧'
    end

    it 'keeps the key readable as-is for dotted/underscored/slashed keys' do
      expect(described_class.encode('en.foo_bar.baz/qux')).to eq '⟦CT:en.foo_bar.baz/qux⟧'
    end

    it 'keeps multibyte keys readable' do
      expect(described_class.encode('ja.見出し')).to eq '⟦CT:ja.見出し⟧'
    end
  end

  describe '::SCAN_REGEXP' do
    it 'captures the key from an encoded token' do
      key = 'views.home.index.message'
      match = described_class::SCAN_REGEXP.match(described_class.encode(key))
      expect(match[1]).to eq key
    end

    it 'captures keys containing dots, underscores, slashes and multibyte' do
      key = 'ja.foo_bar.baz/qux.見出し'
      match = described_class::SCAN_REGEXP.match(described_class.encode(key))
      expect(match[1]).to eq key
    end

    it 'matches non-greedily so adjacent tokens are separated' do
      text = "#{described_class.encode('a.b')}hello#{described_class.encode('c.d')}"
      expect(text.scan(described_class::SCAN_REGEXP).flatten).to eq ['a.b', 'c.d']
    end

    it 'does not match plain text' do
      expect('just a normal sentence with CT: and brackets [x]').not_to match described_class::SCAN_REGEXP
    end
  end
end

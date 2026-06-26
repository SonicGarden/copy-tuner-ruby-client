require 'spec_helper'
require 'copy_tuner_client/copyray/marker'

describe CopyTunerClient::Copyray::Marker do
  describe '.encode' do
    it 'キーを可視トークンの区切り記号で囲む' do
      expect(described_class.encode('views.home.index.message')).to eq '⟦CT:views.home.index.message⟧'
    end

    it 'ドット・アンダースコア・スラッシュを含むキーをそのまま保持する' do
      expect(described_class.encode('en.foo_bar.baz/qux')).to eq '⟦CT:en.foo_bar.baz/qux⟧'
    end

    it 'マルチバイトキーをそのまま保持する' do
      expect(described_class.encode('ja.見出し')).to eq '⟦CT:ja.見出し⟧'
    end
  end

  describe '::SCAN_REGEXP' do
    it 'エンコード済みトークンからキーを取り出す' do
      key = 'views.home.index.message'
      match = described_class::SCAN_REGEXP.match(described_class.encode(key))
      expect(match[1]).to eq key
    end

    it 'ドット・アンダースコア・スラッシュ・マルチバイトを含むキーを取り出す' do
      key = 'ja.foo_bar.baz/qux.見出し'
      match = described_class::SCAN_REGEXP.match(described_class.encode(key))
      expect(match[1]).to eq key
    end

    it '非貪欲マッチで隣接するトークンを分離する' do
      text = "#{described_class.encode('a.b')}hello#{described_class.encode('c.d')}"
      expect(text.scan(described_class::SCAN_REGEXP).flatten).to eq ['a.b', 'c.d']
    end

    it 'プレーンテキストにはマッチしない' do
      expect('just a normal sentence with CT: and brackets [x]').not_to match described_class::SCAN_REGEXP
    end
  end
end

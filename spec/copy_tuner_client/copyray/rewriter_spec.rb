require 'spec_helper'
require 'copy_tuner_client/copyray/marker'
require 'copy_tuner_client/copyray/rewriter'

describe CopyTunerClient::Copyray::Rewriter do
  def marker(key)
    CopyTunerClient::Copyray::Marker.encode(key)
  end

  def ascii8(str)
    str.dup.force_encoding(Encoding::ASCII_8BIT)
  end

  describe '.rewrite' do
    subject(:result) { described_class.rewrite(html) }

    context 'simple text node directly under an element' do
      let(:html) { "<html><body><p>#{marker('a.b')}Hello</p></body></html>" }

      it 'adds data-copyray-key to the parent element' do
        expect(result).to include('data-copyray-key="a.b"')
      end

      it 'removes the marker token' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(result).to include('>Hello<')
      end
    end

    context 'plain translation whose body was html-escaped by ActionView (token left intact)' do
      # NOTE: 平文訳文は ActionView がエスケープするため body の & < > はエンティティ化するが、
      # トークンの区切り記号 ⟦⟧ は HTML 特殊文字ではないので無傷で残る。Rewriter はこれを拾えること。
      let(:html) { "<html><body><p>#{marker('plain.key')}Hello &amp; &lt;World&gt;</p></body></html>" }

      it 'still annotates the element and removes the token, leaving the escaped body untouched' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'plain.key'
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(result).to include('Hello &amp; &lt;World&gt;')
      end
    end

    context 'marker inside a nested inline element' do
      let(:html) { "<html><body><p>foo <a>#{marker('link.key')}Hi</a> bar</p></body></html>" }

      it 'adds the attribute to the nearest parent element (the <a>)' do
        fragment = Nokogiri::HTML(result)
        a = fragment.at_css('a')
        expect(a['data-copyray-key']).to eq 'link.key'
        expect(fragment.at_css('p')['data-copyray-key']).to be_nil
      end
    end

    context 'marker in the middle of a text run' do
      let(:html) { "<html><body><p>foo #{marker('mid.key')}Hi</p></body></html>" }

      it 'adds the attribute to the containing element' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'mid.key'
      end
    end

    context 'marker in an attribute value' do
      let(:html) { %(<html><body><input placeholder="#{marker('search.placeholder')}検索"></body></html>) }

      it 'adds data-copyray-key to the element itself' do
        expect(Nokogiri::HTML(result).at_css('input')['data-copyray-key']).to eq 'search.placeholder'
      end

      it 'strips the token from the attribute value' do
        placeholder = Nokogiri::HTML(result).at_css('input')['placeholder']
        expect(placeholder).to eq '検索'
      end
    end

    context 'marker inside the head (title)' do
      let(:html) { "<html><head><title>#{marker('page.title')}タイトル</title></head><body></body></html>" }

      it 'removes the token' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(Nokogiri::HTML(result).at_css('title').text).to eq 'タイトル'
      end
    end

    context 'multiple markers on the same element' do
      let(:html) { "<html><body><p>#{marker('first.key')}A#{marker('second.key')}B</p></body></html>" }

      it 'uses only the first key for the attribute' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'first.key'
      end

      it 'removes all tokens' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end

    context 'html without any marker' do
      let(:html) { '<html><body><p>Nothing to see</p></body></html>' }

      it 'returns the html unchanged (no-op fast path)' do
        expect(result).to eq html
      end
    end

    context 'body that has fallen back to ASCII-8BIT but contains a marker' do
      let(:html) { ascii8("<html><body><p>#{marker('a.b')}日本語</p></body></html>") }

      it 'does not raise and annotates the parent element' do
        expect { result }.not_to raise_error
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'a.b'
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end

    context 'ASCII-8BIT body without any marker' do
      let(:html) { ascii8('<html><body><p>日本語</p></body></html>') }

      it 'does not raise and returns unchanged' do
        expect { result }.not_to raise_error
      end

      it 'leaves the original string encoding intact' do
        result
        expect(html.encoding).to eq Encoding::ASCII_8BIT
      end
    end

    context 'output never retains any marker token' do
      let(:html) do
        "<html><head><title>#{marker('t')}T</title></head>" \
          "<body><input placeholder=\"#{marker('p')}x\"><p>#{marker('a')}A<a>#{marker('b')}B</a></p></body></html>"
      end

      it 'has no leftover token in the serialized output' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end
  end
end

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

    context '要素直下の単純なテキストノード' do
      let(:html) { "<html><body><p>#{marker('a.b')}Hello</p></body></html>" }

      it '親要素に data-copyray-key を付与する' do
        expect(result).to include('data-copyray-key="a.b"')
      end

      it 'マーカートークンを除去する' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(result).to include('>Hello<')
      end
    end

    context 'ActionView が body を html エスケープした平文訳文（トークンは無傷）' do
      # NOTE: 平文訳文は ActionView がエスケープするため body の & < > はエンティティ化するが、
      # トークンの区切り記号 ⟦⟧ は HTML 特殊文字ではないので無傷で残る。Rewriter はこれを拾えること。
      let(:html) { "<html><body><p>#{marker('plain.key')}Hello &amp; &lt;World&gt;</p></body></html>" }

      it '要素に属性を付与しトークンを除去するが、エスケープ済み body はそのまま残す' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'plain.key'
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(result).to include('Hello &amp; &lt;World&gt;')
      end
    end

    context 'ネストしたインライン要素内のマーカー' do
      let(:html) { "<html><body><p>foo <a>#{marker('link.key')}Hi</a> bar</p></body></html>" }

      it '最も近い親要素（<a>）に属性を付与する' do
        fragment = Nokogiri::HTML(result)
        a = fragment.at_css('a')
        expect(a['data-copyray-key']).to eq 'link.key'
        expect(fragment.at_css('p')['data-copyray-key']).to be_nil
      end
    end

    context 'テキスト中間に置かれたマーカー' do
      let(:html) { "<html><body><p>foo #{marker('mid.key')}Hi</p></body></html>" }

      it '内包する要素に属性を付与する' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'mid.key'
      end
    end

    context '属性値の中のマーカー' do
      let(:html) { %(<html><body><input placeholder="#{marker('search.placeholder')}検索"></body></html>) }

      it '要素自身に data-copyray-key を付与する' do
        expect(Nokogiri::HTML(result).at_css('input')['data-copyray-key']).to eq 'search.placeholder'
      end

      it '属性値からトークンを除去する' do
        placeholder = Nokogiri::HTML(result).at_css('input')['placeholder']
        expect(placeholder).to eq '検索'
      end
    end

    context 'head（title）の中のマーカー' do
      let(:html) { "<html><head><title>#{marker('page.title')}タイトル</title></head><body></body></html>" }

      it 'トークンを除去する' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(Nokogiri::HTML(result).at_css('title').text).to eq 'タイトル'
      end
    end

    context '同一テキストノード内の複数マーカー' do
      let(:html) { "<html><body><p>#{marker('first.key')}A#{marker('second.key')}B</p></body></html>" }

      it 'すべてのキーをカンマ区切りで data-copyray-key に保持する' do
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'first.key,second.key'
      end

      it 'すべてのトークンを除去する' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end

    context '同一属性値内の複数マーカー' do
      let(:html) { %(<html><body><input placeholder="#{marker('a.key')}x#{marker('b.key')}y"></body></html>) }

      it 'すべてのキーをカンマ区切りで data-copyray-key に保持する' do
        expect(Nokogiri::HTML(result).at_css('input')['data-copyray-key']).to eq 'a.key,b.key'
      end

      it '属性値からすべてのトークンを除去する' do
        expect(Nokogiri::HTML(result).at_css('input')['placeholder']).to eq 'xy'
      end
    end

    context 'マーカーが無い html' do
      let(:html) { '<html><body><p>Nothing to see</p></body></html>' }

      it 'html を無変形で返す（no-op 高速パス）' do
        expect(result).to eq html
      end
    end

    context 'ASCII-8BIT に転落したがマーカーを含む body' do
      let(:html) { ascii8("<html><body><p>#{marker('a.b')}日本語</p></body></html>") }

      it '例外を投げず親要素に属性を付与する' do
        expect { result }.not_to raise_error
        expect(Nokogiri::HTML(result).at_css('p')['data-copyray-key']).to eq 'a.b'
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end

    context 'マーカーが無い ASCII-8BIT の body' do
      let(:html) { ascii8('<html><body><p>日本語</p></body></html>') }

      it '例外を投げず無変形で返す' do
        expect { result }.not_to raise_error
      end

      it '渡された文字列のエンコーディングを破壊しない' do
        result
        expect(html.encoding).to eq Encoding::ASCII_8BIT
      end
    end

    context 'rewrite が内部で例外を投げる' do
      # NOTE: 壊れた HTML 等で Nokogiri 処理が例外を投げる状況を模す。
      #       Copyray は開発支援機能なので、ここでページを 500 にしない（フォールバック動作）。
      let(:html) { "<html><body><p>#{marker('a.b')}Hello</p></body></html>" }

      before do
        allow(described_class).to receive(:rewrite_with_nokogiri).and_raise(RuntimeError, 'boom')
      end

      it '例外を伝播させずトークンだけ除去して返す' do
        expect { result }.not_to raise_error
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
        expect(result).to include('<p>Hello</p>')
      end

      it 'logger.warn で例外内容を記録する' do
        logger = double('logger')
        allow(CopyTunerClient.configuration).to receive(:logger).and_return(logger)
        expect(logger).to receive(:warn).with(/Rewriter failed.*RuntimeError.*boom/)
        result
      end

      it 'logger が nil でもフォールバックが落ちない' do
        allow(CopyTunerClient.configuration).to receive(:logger).and_return(nil)
        expect { result }.not_to raise_error
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end

    context '出力にマーカートークンが一切残らない' do
      let(:html) do
        "<html><head><title>#{marker('t')}T</title></head>" \
          "<body><input placeholder=\"#{marker('p')}x\"><p>#{marker('a')}A<a>#{marker('b')}B</a></p></body></html>"
      end

      it 'シリアライズ後の出力にトークンが残っていない' do
        expect(result).not_to match CopyTunerClient::Copyray::Marker::SCAN_REGEXP
      end
    end
  end
end

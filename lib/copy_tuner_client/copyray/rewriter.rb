require 'nokogiri'
require 'copy_tuner_client/copyray/marker'

module CopyTunerClient
  class Copyray
    # 完成 HTML を走査し、マーカートークンを含むテキストノードの親要素・属性値を持つ要素に
    # data-copyray-key 属性を付与し、トークンを完全に除去する。
    # CopyrayMiddleware の HTML 後処理（CSS/JS 挿入）の前段で呼ばれる。
    module Rewriter
      DATA_ATTR = 'data-copyray-key'.freeze

      module_function

      def rewrite(html)
        # NOTE: ボディが ASCII-8BIT に転落していると UTF-8 の Marker::PREFIX との include? 比較が
        # Encoding::CompatibilityError を投げる（ミドルウェアのボディ連結で非ASCIIバイトを含む
        # ASCII-8BIT チャンクが混じると発生）。実バイト列は本来 UTF-8 なので判定用に UTF-8 とみなす。
        # String.new でエンコーディングだけ付け替える（元オブジェクトを破壊せずバッファもコピーしない）。
        scannable = html.encoding == Encoding::UTF_8 ? html : String.new(html, encoding: Encoding::UTF_8)

        # NOTE: マーカーが無ければ Copyray 無効時・通常ページなので一切変形しない（高速パス）。
        # これにより本番（マーカー非注入）の HTML は完全に無傷で、Nokogiri の正規化も通らない。
        # 判定は正規表現より安い部分文字列検索で行う（プレフィックスがあれば必ずマーカー候補）。
        return html unless scannable.include?(Marker::PREFIX)

        doc = Nokogiri::HTML(scannable)

        doc.traverse do |node|
          if node.text?
            annotate_text_node(node)
          elsif node.element?
            annotate_attributes(node)
          end
        end

        # NOTE: Nokogiri 走査はテキストノード親要素・属性値への属性付与とノード単位の除去を担うが、
        # serialize 時の正規化（エンティティ復元等）でトークンが復活しうる縁を塞ぐため、
        # 最終出力にもう一度 gsub をかけて残留トークンを保険で全除去する（可視トークンの除去漏れは画面に出るため）。
        doc.to_html.gsub(Marker::SCAN_REGEXP, '')
      end

      def annotate_text_node(node)
        match = node.content.match(Marker::SCAN_REGEXP)
        return unless match

        set_key(node.parent, match[1])
        node.content = node.content.gsub(Marker::SCAN_REGEXP, '')
      end

      def annotate_attributes(element)
        element.attribute_nodes.each do |attr|
          match = attr.value.match(Marker::SCAN_REGEXP)
          next unless match

          set_key(element, match[1])
          attr.value = attr.value.gsub(Marker::SCAN_REGEXP, '')
        end
      end

      # 最初のマーカー優先：既に属性が付いている要素には上書きしない。
      def set_key(element, key)
        return if element.nil? || !element.element?
        return if element[DATA_ATTR]

        element[DATA_ATTR] = key
      end
    end
  end
end

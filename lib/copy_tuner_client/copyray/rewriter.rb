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

        rewrite_with_nokogiri(scannable)
      rescue StandardError => e
        # NOTE: Copyray は開発支援機能なので、壊れた HTML 等で Nokogiri 処理が落ちても
        # ページを 500 にしない。data-copyray-key 付与（編集導線）は諦め、最低限可視トークンだけ除去する。
        # gsub 対象が html ではなく scannable なのは、ASCII-8BIT のままだと UTF-8 の
        # SCAN_REGEXP との比較で Encoding::CompatibilityError が再発しうるため。
        warn_rewrite_failure(e)
        scannable.gsub(Marker::SCAN_REGEXP, '')
      end

      def rewrite_with_nokogiri(scannable)
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

      # NOTE: logger 未設定の構成でもフォールバック自体が落ちないよう nil ガードする。
      def warn_rewrite_failure(error)
        logger = CopyTunerClient.configuration.logger
        logger&.warn("CopyTuner Copyray::Rewriter failed: #{error.class.name}: #{error.message}")
      end

      def annotate_text_node(node)
        keys = scan_keys(node.content)
        return if keys.empty?

        set_keys(node.parent, keys)
        node.content = node.content.gsub(Marker::SCAN_REGEXP, '')
      end

      def annotate_attributes(element)
        element.attribute_nodes.each do |attr|
          keys = scan_keys(attr.value)
          next if keys.empty?

          set_keys(element, keys)
          attr.value = attr.value.gsub(Marker::SCAN_REGEXP, '')
        end
      end

      # NOTE: 空キーは除く（JS 側も split 後に空要素を捨てるため、表現を両端で揃える）。
      def scan_keys(text)
        text.scan(Marker::SCAN_REGEXP).flatten.reject(&:empty?)
      end

      # NOTE: 同一テキストノード／属性値に複数マーカーが連結されると全キーをここで受け取り、
      # 1 要素に複数キーをカンマ区切りで保持する（1 要素 1 キーだと 2 個目以降の編集導線が消える）。
      # 既存値がある場合（同じ要素を複数経路で踏むケース）はマージして重複排除し、出現順を保つ。
      # I18n キーに ',' は通常含まれないため区切り文字として安全。JS 側もカンマ区切りを前提に読む。
      def set_keys(element, keys)
        return if element.nil? || !element.element?

        existing = element[DATA_ATTR]&.split(',') || []
        element[DATA_ATTR] = (existing + keys).uniq.join(',')
      end
    end
  end
end

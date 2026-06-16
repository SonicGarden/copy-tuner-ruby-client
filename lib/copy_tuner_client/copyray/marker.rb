module CopyTunerClient
  class Copyray
    # 訳文に埋め込むキーマーカーの可視テキストトークン。
    # サーバ側（CopyrayMiddleware の Rewriter）だけが encode/scan/strip すればよく、
    # フロントは data 属性化された後の DOM を見るので decode は不要。
    #
    # 例: encode('views.home.message') #=> "⟦CT:views.home.message⟧"
    module Marker
      # NOTE: 通常の本文・属性値に出現しない記号（U+27E6 / U+27E7）と固定プレフィックス CT: で
      # 偶発衝突を二重に下げる。除去漏れても可読なので人間が原因に気づける（不可視文字は不採用）。
      PREFIX = '⟦CT:'.freeze
      SUFFIX = '⟧'.freeze

      # NOTE: PREFIX/SUFFIX から動的構築し、区切り変更時に encode と SCAN_REGEXP がズレないようにする。
      SCAN_REGEXP = /#{Regexp.escape(PREFIX)}(.*?)#{Regexp.escape(SUFFIX)}/

      module_function

      def encode(key)
        "#{PREFIX}#{key}#{SUFFIX}"
      end
    end
  end
end

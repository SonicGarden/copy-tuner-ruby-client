require 'copy_tuner_client/copyray/marker'

module CopyTunerClient
  class Copyray
    # This:
    #   message
    # Becomes:
    #   ⟦CT:views.home.index.message⟧message
    # マーカートークンは CopyrayMiddleware の Rewriter で data-copyray-key 属性に変換され、HTML から除去される。
    def self.augment_template(source, key)
      return source if source.blank? || !source.is_a?(String)

      # NOTE: local_first（CopyTuner 管理外でローカル config/locales 優先）のキーには
      # オーバーレイマーカーを出さない。編集できないキーを編集可能だと誤認させないため。
      return source if CopyTunerClient.configuration.local_first_key?(key)

      # NOTE: マーカーは平文・html_safe どちらの訳文にも埋め込む（画面に出る全テキストをオーバーレイ対象にする）。
      # トークンの区切り記号 ⟦⟧ は HTML 特殊文字ではないため、平文が ActionView でエスケープされても無傷で残り、
      # Rewriter の走査は崩れない。
      # html_safe フラグは source のものを引き継ぐ。html_safe を勝手に立てると平文訳文の本体（& < >）が
      # エスケープされず XSS になり、逆に html_safe を落とすと _html 訳文がエスケープされて壊れるため。
      augmented = Marker.encode(key) + source
      source.html_safe? ? augmented.html_safe : augmented
    end
  end
end

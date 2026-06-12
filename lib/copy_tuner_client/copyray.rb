require 'copy_tuner_client/subliminal'

module CopyTunerClient
  class Copyray
    # Wraps a resolved translation so the browser overlay can locate its key.
    #
    # :comment mode (default):
    #   message  ->  <!--COPYRAY views.home.index.message-->message  (always html_safe)
    # :subliminal mode:
    #   message  ->  [invisible marker]message  (html_safe state of the source is preserved)
    def self.augment_template(source, key)
      return source if source.blank? || !source.is_a?(String)

      # NOTE: local_first（CopyTuner 管理外でローカル config/locales 優先）のキーには
      # オーバーレイマーカーを出さない。編集できないキーを編集可能だと誤認させないため。
      return source if CopyTunerClient.configuration.local_first_key?(key)

      if CopyTunerClient.configuration.copyray_marker_type == :subliminal
        augment_with_subliminal(source, key)
      else
        augment_with_comment(source, key)
      end
    end

    def self.augment_with_comment(source, key)
      escape = CopyTunerClient.configuration.html_escape && !source.html_safe?
      augmented = "<!--COPYRAY #{key}-->#{escape ? ERB::Util.html_escape(source) : source}"
      augmented.html_safe
    end

    # 不可視文字でキーを前置する。不可視文字は HTML 特殊文字ではないため、
    # source の html_safe 状態をそのまま引き継いでも安全（Rails 標準互換）。
    def self.augment_with_subliminal(source, key)
      marked = "#{CopyTunerClient::Subliminal.encode(key)}#{source}"
      source.html_safe? ? marked.html_safe : marked
    end
  end
end

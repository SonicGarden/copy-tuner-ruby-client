module CopyTunerClient
  class Copyray
    # This:
    #   message
    # Becomes:
    #   <!--COPYRAY views.home.index.message-->message
    def self.augment_template(source, key)
      return source if source.blank? || !source.is_a?(String)

      # NOTE: local_first（CopyTuner 管理外でローカル config/locales 優先）のキーには
      # オーバーレイマーカーを出さない。編集できないキーを編集可能だと誤認させないため。
      return source if CopyTunerClient.configuration.local_first_key?(key)

      escape = CopyTunerClient.configuration.html_escape && !source.html_safe?
      augmented = "<!--COPYRAY #{key}-->#{escape ? ERB::Util.html_escape(source) : source}"
      augmented.html_safe
    end
  end
end

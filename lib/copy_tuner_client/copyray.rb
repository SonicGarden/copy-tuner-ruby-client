module CopyTunerClient
  class Copyray
    # This:
    #   message
    # Becomes:
    #   <!--COPYRAY views.home.index.message-->message
    def self.augment_template(source, key)
      return source if source.blank? || !source.is_a?(String)

      escape = CopyTunerClient.configuration.html_escape && !source.html_safe?
      augmented = "<!--COPYRAY #{key}-->#{escape ? ERB::Util.html_escape(source) : source}"
      augmented.html_safe
    end
  end
end

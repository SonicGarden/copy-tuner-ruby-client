module CopyTunerClient
  class TranslationLog
    def self.translations
      Thread.current[:translations]
    end

    def self.clear
      Thread.current[:translations] = {}
    end

    def self.initialized?
      !Thread.current[:translations].nil?
    end

    def self.add(key, result)
      translations[key] = result if initialized? && !translations.key?(key)
    end

    def self.install_hook
      I18n.class_eval do
        class << self
          def translate_with_copy_tuner_hook(key = nil, **options)
            scope = options[:scope]
            scope = scope.dup if scope.is_a?(Array) || scope.is_a?(String)
            result = translate_without_copy_tuner_hook(key, **options)

            if key.is_a?(Array)
              key.zip(result).each { |k, v| CopyTunerClient::TranslationLog.add(I18n.normalize_keys(nil, k, scope).compact.join('.'), v) unless v.is_a?(Array) }
            else
              CopyTunerClient::TranslationLog.add(I18n.normalize_keys(nil, key, scope).compact.join('.'), result) unless result.is_a?(Array)
            end
            result
          end

          if CopyTunerClient.configuration.enable_middleware?
            alias_method :translate_without_copy_tuner_hook, :translate
            alias_method :translate, :translate_with_copy_tuner_hook
            alias :t :translate
          end
        end
      end
    end
  end
end

module CopyTunerClient
  module HelperExtension
    class << self
      def hook_translation_helper(mod, middleware_enabled:)
        mod.class_eval do
          def translate_with_copyray_comment(key, **options)
            source = translate_without_copyray_comment(key, **options)

            if controller && CopyTunerClient::Rails.controller_of_rails_engine?(controller)
              return source
            end

            # TODO: test
            # NOTE: default引数が設定されている場合は、copytunerキャッシュの値をI18n.t呼び出しにより上書きしている
            # SEE: https://github.com/rails/rails/blob/6c43ebc220428ce9fc9569c2e5df90a38a4fc4e4/actionview/lib/action_view/helpers/translation_helper.rb#L82
            I18n.t(key, **options) if options.key?(:default)

            if CopyTunerClient.configuration.disable_copyray_comment_injection
              source
            else
              separator = options[:separator] || I18n.default_separator
              scope = options[:scope]
              normalized_key =
                if key.to_s.first == '.'
                  scope_key_by_partial(key)
                else
                  I18n.normalize_keys(nil, key, scope, separator).join(separator)
                end
              CopyTunerClient::Copyray.augment_template(source, normalized_key)
            end
          end
          if middleware_enabled
            alias_method :translate_without_copyray_comment, :translate
            alias_method :translate, :translate_with_copyray_comment
            alias :t :translate
            alias :tt :translate_without_copyray_comment
          else
            alias :tt :translate
          end
        end
      end
    end
  end
end

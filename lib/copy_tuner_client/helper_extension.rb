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

            # NOTE: マーカー注入は最終的に Rack を通って CopyrayMiddleware で除去される HTML レスポンスの
            # 描画のときだけ行う。メール本文・render :json・CSV/PDF など非 HTML 経路では除去されず
            # コメントが残るため、それらの経路には注入しない。
            return source unless copyray_injectable?

            # TODO: test
            # NOTE: default引数が設定されている場合は、copytunerキャッシュの値をI18n.t呼び出しにより上書きしている
            # SEE: https://github.com/rails/rails/blob/6c43ebc220428ce9fc9569c2e5df90a38a4fc4e4/actionview/lib/action_view/helpers/translation_helper.rb#L82
            if options.key?(:default)
              I18n.t(key.to_s.first == '.' ? scope_key_by_partial(key) : key, **options)
            end

            if CopyTunerClient.configuration.disable_copyray_comment_injection
              source
            else
              separator = options[:separator] || I18n.default_separator
              scope = options[:scope]
              scope_key =
                if key.to_s.first == '.'
                  scope_key_by_partial(key)
                else
                  # NOTE: locale prefix無しのkeyが必要のためこうしている
                  I18n.normalize_keys(nil, key, scope, separator).compact.join(separator)
                end
              CopyTunerClient::Copyray.augment_template(source, scope_key)
            end
          end

          # NOTE: 描画中のフォーマットが HTML で、かつ mailer 以外の描画文脈のときだけ true。
          # @current_template.format が描画中テンプレートのフォーマットを最も正確に表す。
          # render html: 等で @current_template が nil のときは lookup_context.formats.first にフォールバック。
          def copyray_injectable?
            format = @current_template&.format || lookup_context.formats.first
            return false unless format == :html

            # NOTE: mailer の HTML パートも format は :html になるため format 判定だけでは除外できない。明示除外する。
            current_controller = controller
            return false if current_controller.nil?
            return false if defined?(ActionMailer::Base) && current_controller.is_a?(ActionMailer::Base)

            true
          end
          private :copyray_injectable?

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

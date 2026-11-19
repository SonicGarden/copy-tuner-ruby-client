require 'copy_tuner_client/copyray'

module CopyTunerClient
  # ActionView の translate/t を差し替えて Copyray のオーバーレイマーカーを注入し、注入してよい描画経路を制御する
  module HelperExtension
    # NOTE: class_eval ブロック内で def すると、ブロック内メソッドの複雑さが
    # hook_translation_helper 自体の Metrics/AbcSize としてカウントされてしまうため、
    # メソッド本体は独立したモジュールに切り出して include する。
    module CopyrayCommentInjection
      def translate_with_copyray_comment(key, **options)
        source = translate_without_copyray_comment(key, **options)

        return source if controller && CopyTunerClient::Rails.controller_of_rails_engine?(controller)

        # TODO: test
        # NOTE: default引数が設定されている場合は、copytunerキャッシュの値をI18n.t呼び出しにより上書きしている
        # SEE: https://github.com/rails/rails/blob/6c43ebc220428ce9fc9569c2e5df90a38a4fc4e4/actionview/lib/action_view/helpers/translation_helper.rb#L82
        if options.key?(:default)
          I18n.t(key.to_s.first == '.' ? scope_key_by_partial(key) : key, **options)
        end

        # NOTE: マーカーは HTML コメントとしてブラウザに無視されつつ Copyray オーバーレイのキー特定に
        # 使われる。HTML 以外の経路（メール本文・render :json・CSV/PDF など）ではコメントが文字列として
        # 出力に混入してしまうため、それらの経路には注入しない。default 引数による初期値登録は維持する
        # 必要があるため、このガードは初期値登録（上の I18n.t 呼び出し）より後に置く。
        return source unless CopyTunerClient::Copyray.injectable?(controller)

        CopyTunerClient::Copyray.augment_template(source, copyray_scope_key(key, options))
      end

      def copyray_scope_key(key, options)
        return scope_key_by_partial(key) if key.to_s.first == '.'

        separator = options.fetch(:separator, I18n.default_separator)
        # NOTE: locale prefix無しのkeyが必要のためこうしている
        I18n.normalize_keys(nil, key, options[:scope], separator).compact.join(separator)
      end
      private :copyray_scope_key
    end
    private_constant :CopyrayCommentInjection

    # NOTE: render_to_string の結果は PDF 化や JSON 埋め込みなどレスポンス以外に使われ、middleware の
    # 書き換えを通らない。実行中だけ印を外し、その間の translate にマーカーを注入させない。
    module RenderToStringGuard
      def render_to_string(*, **, &)
        env = request&.env
        return super unless env&.delete(CopyTunerClient::Copyray::ENV_KEY)

        begin
          super
        ensure
          env[CopyTunerClient::Copyray::ENV_KEY] = true
        end
      end
    end
    private_constant :RenderToStringGuard

    def self.hook_translation_helper(mod, middleware_enabled:)
      return unless middleware_enabled

      mod.include(CopyrayCommentInjection)
      mod.class_eval do
        alias_method :translate_without_copyray_comment, :translate
        alias_method :translate, :translate_with_copyray_comment
        alias_method :t, :translate
      end
    end

    def self.hook_render_to_string(mod, middleware_enabled:)
      return unless middleware_enabled

      mod.prepend(RenderToStringGuard)
    end
  end
end

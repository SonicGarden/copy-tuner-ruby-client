require 'copy_tuner_client/copyray/marker'

module CopyTunerClient
  # 翻訳テキストにオーバーレイ編集用のマーカートークンを埋め込む
  class Copyray
    # NOTE: マーカーは CopyrayMiddleware の Rewriter でしか除去されない。注入可否を「format が html か」ではなく
    # 「この描画の出力が middleware を通るか」で判定するため、middleware が env にこの印を立てる。
    ENV_KEY = 'copy_tuner.copyray_injectable'.freeze

    # NOTE: HTML 以外の経路（メール本文・render :json・CSV/PDF など）ではマーカーが文字列として
    # 出力に混入するため注入しない。判定には controller.request.format を使い、@current_template.format /
    # lookup_context.formats のような ActionView の内部実装には依存させない（Rails バージョン間で壊れうるため）。
    def self.injectable?(controller)
      return false if CopyTunerClient.configuration.disable_copyray_comment_injection
      return false if controller.nil?

      # NOTE: mailer は request を持たず request.format で判定できない。かつメール本文への
      # マーカー混入は実害が大きいため、controller の型で明示除外する。
      return false if defined?(ActionMailer::Base) && controller.is_a?(ActionMailer::Base)

      rewritable_request?(controller.request)
    end

    def self.rewritable_request?(request)
      # NOTE: format が html でも出力が CopyrayMiddleware を通らない経路（ApplicationController.renderer や
      # render_to_string）ではマーカーが除去されずに残るため、middleware が立てた印がある場合に限り注入する。
      return false unless request&.env&.[](ENV_KEY)

      # NOTE: middleware を通っても render json: などは rewritable? に弾かれ書き換えられないため、
      # format が html でない経路には注入しない。
      request.format&.html? || false
    end
    private_class_method :rewritable_request?

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

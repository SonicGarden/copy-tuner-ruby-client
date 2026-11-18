require 'copy_tuner_client/copyray'

begin
  require 'simple_form'
rescue LoadError
  # simple_form は任意依存のため、未導入環境では以降の拡張定義自体をスキップする
end

if defined?(SimpleForm)
  # SimpleForm のラベル生成に Copyray のオーバーレイマーカーを注入する
  module SimpleForm::Components::Labels
    protected

    def label_translation_with_copyray_comment
      source = label_translation_without_copyray_comment

      # NOTE: translate と同じ判定で注入可否を決める。jQuery で画面を差し替える JS 応答などは
      # CopyrayMiddleware の書き換え対象外で、注入するとマーカーが除去されずに画面に出るため。
      if !CopyTunerClient.configuration.disable_copyray_comment_injection &&
         object.class.respond_to?(:lookup_ancestors) &&
         template.__send__(:copyray_injectable?)
        attributes_scope = "#{object.class.i18n_scope}.attributes"
        defaults =
          object.class.lookup_ancestors.map do |klass|
            "#{attributes_scope}.#{klass.model_name.i18n_key}.#{reflection_or_attribute_name}"
          end
        CopyTunerClient::Copyray.augment_template(source, defaults.shift)
      else
        source
      end
    end
    if CopyTunerClient.configuration.enable_middleware?
      alias label_translation_without_copyray_comment label_translation
      alias label_translation label_translation_with_copyray_comment
    end
  end
end

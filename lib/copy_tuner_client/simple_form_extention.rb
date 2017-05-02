require 'copy_tuner_client/copyray'

begin
  require "simple_form"
rescue LoadError
end

if defined?(SimpleForm)
  module SimpleForm::Components::Labels
    module LabelTranslationWrapper
      def label_translation
        source = super

        if !CopyTunerClient.configuration.disable_copyray_comment_injection && object.class.respond_to?(:lookup_ancestors)
          attributes_scope = "#{object.class.i18n_scope}.attributes"
          defaults = object.class.lookup_ancestors.map do |klass|
            "#{attributes_scope}.#{klass.model_name.i18n_key}.#{reflection_or_attribute_name}"
          end
          CopyTunerClient::Copyray.augment_template(source, defaults.shift).html_safe
        else
          source
        end
      end
    end

    if CopyTunerClient.configuration.enable_middleware?
      prepend SimpleForm::Components::Labels::LabelTranslationWrapper
    end
  end
end

require 'spec_helper'
require 'active_model'
require 'copy_tuner_client/copyray'

# NOTE: simple_form は開発依存に含めていないため、ラベル生成部品（SimpleForm::Components::Labels）を
# 最小のフェイクで用意し、そこへ拡張を読み込ませて注入ガードだけを検証する。
describe 'SimpleForm::Components::Labels の Copyray 拡張' do # rubocop:disable RSpec/DescribeClass
  let(:labels_module) do
    Module.new do
      def label_translation
        '体温'
      end
    end
  end

  let(:model_class) do
    Class.new do
      include ActiveModel::Model

      def self.name
        'BodyTemperatureRecord'
      end
    end
  end

  let(:input_class) do
    labels = labels_module
    Struct.new(:object, :template) do
      include labels

      def reflection_or_attribute_name
        :value
      end
    end
  end

  # NOTE: 注入可否の判定そのものは helper_extension_spec で検証済みなので、
  # ここではビューの copyray_injectable? の結果に従うことだけを見る。
  def template_with(injectable:)
    template_class =
      Class.new do
        define_method(:copyray_injectable?) { injectable }
        private :copyray_injectable?
      end
    template_class.new
  end

  def label_for(template)
    input_class.new(model_class.new, template).__send__(:label_translation)
  end

  before do
    stub_const('SimpleForm::Components::Labels', labels_module)
    allow(CopyTunerClient.configuration).to receive(:enable_middleware?).and_return(true)
    load File.join(PROJECT_ROOT, 'lib', 'copy_tuner_client', 'simple_form_extention.rb')
  end

  it 'ビューが注入可能と判定したときはラベルにマーカーを注入する' do
    expect(label_for(template_with(injectable: true)))
      .to eq '⟦CT:activemodel.attributes.body_temperature_record.value⟧体温'
  end

  it 'ビューが注入不可と判定したとき（JS 応答など）はラベルにマーカーを注入しない' do
    expect(label_for(template_with(injectable: false))).to eq '体温'
  end
end

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

  let(:controller) { Object.new }
  let(:template) { Struct.new(:controller).new(controller) }

  # NOTE: 注入可否の判定そのものは Copyray.injectable? の spec で検証済みなので、
  # ここではその結果に従うことだけを見る。
  def label_for
    input_class.new(model_class.new, template).__send__(:label_translation)
  end

  before do
    stub_const('SimpleForm::Components::Labels', labels_module)
    allow(CopyTunerClient.configuration).to receive(:enable_middleware?).and_return(true)
    load File.join(PROJECT_ROOT, 'lib', 'copy_tuner_client', 'simple_form_extention.rb')
  end

  it 'Copyray.injectable? が true のときはラベルにマーカーを注入する' do
    allow(CopyTunerClient::Copyray).to receive(:injectable?).with(controller).and_return(true)
    expect(label_for).to eq '⟦CT:activemodel.attributes.body_temperature_record.value⟧体温'
  end

  it 'Copyray.injectable? が false のとき（JS 応答など）はラベルにマーカーを注入しない' do
    allow(CopyTunerClient::Copyray).to receive(:injectable?).with(controller).and_return(false)
    expect(label_for).to eq '体温'
  end
end

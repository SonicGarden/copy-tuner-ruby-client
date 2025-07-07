require 'spec_helper'

describe CopyTunerClient::DottedHash do
  describe ".to_h" do
    subject { CopyTunerClient::DottedHash.to_h(dotted_hash) }

    context 'empty keys' do
      let(:dotted_hash) { {} }

      it { is_expected.to eq({}) }
    end

    context 'with single-level keys' do
      let(:dotted_hash) { { 'key' => 'test value', other_key: 'other value' } }

      it { is_expected.to eq({ 'key' => 'test value', 'other_key' => 'other value' }) }
    end

    context 'array of key value pairs' do
      let(:dotted_hash) { [['key', 'test value'], ['other_key', 'other value']] }

      it { is_expected.to eq({ 'key' => 'test value', 'other_key' => 'other value' }) }
    end

    context "with multi-level blurb keys" do
      let(:dotted_hash) do
        {
          'en.test.key' => 'en test value',
          'en.test.other_key' => 'en other test value',
          'fr.test.key' => 'fr test value',
        }
      end

      it do
        is_expected.to eq({
          'en' => {
            'test' => {
              'key' => 'en test value',
              'other_key' => 'en other test value',
            },
          },
          'fr' => {
            'test' => {
              'key' => 'fr test value',
            },
          },
        })
      end
    end

    context "with conflicting keys" do
      let(:dotted_hash) do
        {
          'en.test' => 'invalid value',
          'en.test.key' => 'en test value',
        }
      end

      it { is_expected.to eq({ 'en' => { 'test' => { 'key' => 'en test value' } } }) }
    end

    context "with Rails i18n numeric precision keys" do
      let(:dotted_hash) do
        {
          'en.number.currency.format.precision' => '2',
          'en.number.format.precision' => '3',
        }
      end

      it "converts precision values to integers" do
        is_expected.to eq({
          'en' => {
            'number' => {
              'currency' => {
                'format' => {
                  'precision' => 2,
                },
              },
              'format' => {
                'precision' => 3,
              },
            },
          },
        })
      end
    end

    context "with Rails i18n boolean keys" do
      let(:dotted_hash) do
        {
          'en.number.currency.format.significant' => 'false',
          'en.number.format.strip_insignificant_zeros' => 'true',
        }
      end

      it "converts boolean values to actual booleans" do
        is_expected.to eq({
          'en' => {
            'number' => {
              'currency' => {
                'format' => {
                  'significant' => false,
                },
              },
              'format' => {
                'strip_insignificant_zeros' => true,
              },
            },
          },
        })
      end
    end

    context "with non-Rails i18n keys containing similar patterns" do
      let(:dotted_hash) do
        {
          'en.custom.precision' => 'custom_value',
          'en.other.significant_value' => 'true',
        }
      end

      it "converts only keys ending with Rails i18n patterns" do
        is_expected.to eq({
          'en' => {
            'custom' => {
              'precision' => 0, # .precision suffix triggers conversion
            },
            'other' => {
              'significant_value' => 'true', # no conversion for non-exact match
            },
          },
        })
      end
    end
  end

  describe ".conflict_keys" do
    subject { CopyTunerClient::DottedHash.conflict_keys(dotted_hash) }

    context 'valid keys' do
      let(:dotted_hash) do
        {
          'ja.hoge.test' => 'test',
          'ja.hoge.fuga' => 'test',
        }
      end

      it { is_expected.to eq({}) }
    end

    context 'invalid keys' do
      let(:dotted_hash) do
        {
          'ja.hoge.test' => 'test',
          'ja.hoge.test.hoge' => 'test',
          'ja.hoge.test.fuga' => 'test',
          'ja.fuga.test.hoge' => 'test',
          'ja.fuga.test' => 'test',
        }
      end

      it do
        is_expected.to eq({
          'ja.fuga.test' => %w[ja.fuga.test.hoge],
          'ja.hoge.test' => %w[ja.hoge.test.fuga ja.hoge.test.hoge],
        })
      end
    end
  end
end

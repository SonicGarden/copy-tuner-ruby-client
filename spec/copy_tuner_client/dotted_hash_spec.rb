require 'spec_helper'

describe CopyTunerClient::DottedHash do
  describe ".to_h" do
    subject { CopyTunerClient::DottedHash.to_h(dotted_hash) }

    context '空のキーの場合' do
      let(:dotted_hash) { {} }

      it { is_expected.to eq({}) }
    end

    context '1階層のキーの場合' do
      let(:dotted_hash) { { 'key' => 'test value', other_key: 'other value' } }

      it { is_expected.to eq({ 'key' => 'test value', 'other_key' => 'other value' }) }
    end

    context 'キーと値の配列の場合' do
      let(:dotted_hash) { [['key', 'test value'], ['other_key', 'other value']] }

      it { is_expected.to eq({ 'key' => 'test value', 'other_key' => 'other value' }) }
    end

    context "複数階層のblurbキーの場合" do
      let(:dotted_hash) do
        {
          'en.test.key' => 'en test value',
          'en.test.other_key' => 'en other test value',
          'fr.test.key' => 'fr test value',
        }
      end

      it "正しくネストされたハッシュに変換されること" do
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

    context "キーの競合がある場合" do
      let(:dotted_hash) do
        {
          'en.test' => 'invalid value',
          'en.test.key' => 'en test value',
        }
      end

      it { is_expected.to eq({ 'en' => { 'test' => { 'key' => 'en test value' } } }) }
    end

    context "Rails i18nの数値precisionキーの場合" do
      let(:dotted_hash) do
        {
          'en.number.currency.format.precision' => '2',
          'en.number.format.precision' => '3',
        }
      end

      it "precision値を整数に変換する" do
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

    context "Rails i18nのbooleanキーの場合" do
      let(:dotted_hash) do
        {
          'en.number.currency.format.significant' => 'false',
          'en.number.format.strip_insignificant_zeros' => 'true',
        }
      end

      it "boolean値を実際の真偽値に変換する" do
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

    context "Rails i18n以外で似たパターンを含むキーの場合" do
      let(:dotted_hash) do
        {
          'en.custom.precision' => 'custom_value',
          'en.other.significant_value' => 'true',
        }
      end

      it "Rails i18nパターンで終わるキーのみ変換する" do
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

    context '有効なキーの場合' do
      let(:dotted_hash) do
        {
          'ja.hoge.test' => 'test',
          'ja.hoge.fuga' => 'test',
        }
      end

      it { is_expected.to eq({}) }
    end

    context '無効なキーの場合' do
      let(:dotted_hash) do
        {
          'ja.hoge.test' => 'test',
          'ja.hoge.test.hoge' => 'test',
          'ja.hoge.test.fuga' => 'test',
          'ja.fuga.test.hoge' => 'test',
          'ja.fuga.test' => 'test',
        }
      end

      it "競合するキーが正しく検出されること" do
        is_expected.to eq({
          'ja.fuga.test' => %w[ja.fuga.test.hoge],
          'ja.hoge.test' => %w[ja.hoge.test.fuga ja.hoge.test.hoge],
        })
      end
    end
  end
end

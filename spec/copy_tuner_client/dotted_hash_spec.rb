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

    # NOTE: number.*.format 配下のキー（precision 等）は I18nBackend の local_first_key? ガードで
    # tree_cache をバイパスしローカル YAML 優先になるため、ここで型変換せず文字列のまま保持する。
    # （number_to_currency が壊れないことは i18n_backend_spec の number ローカル優先テストで担保）
    context "number.*.format 配下の値を含む場合" do
      let(:dotted_hash) do
        {
          'en.number.currency.format.precision' => '2',
          'en.custom.precision' => 'custom_value',
        }
      end

      it "型変換せず値を文字列のまま保持する" do
        is_expected.to eq({
          'en' => {
            'number' => { 'currency' => { 'format' => { 'precision' => '2' } } },
            'custom' => { 'precision' => 'custom_value' },
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

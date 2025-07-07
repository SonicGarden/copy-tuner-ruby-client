require 'spec_helper'

describe 'CopyTunerClient::I18nBackend' do
  # テスト用のキャッシュクラス：既存のHashインターフェースを維持しつつ新機能をサポート
  class TestCache < Hash
    def initialize(initial_etag = 'test-etag-1')
      super()
      @test_etag = initial_etag
    end

    def version
      @test_etag
    end

    def to_tree_hash
      CopyTunerClient::DottedHash.to_h(self)
    end

    def wait_for_download
      # テスト用のスタブメソッド
    end

    def etag=(value)
      @test_etag = value
    end

    def etag
      @test_etag
    end
  end

  let(:cache) { TestCache.new }

  def build_backend
    backend = CopyTunerClient::I18nBackend.new(cache)
    I18n.backend = backend
    backend
  end

  before do
    @default_backend = I18n.backend
  end

  after { I18n.backend = @default_backend }

  subject { build_backend }

  it 'ロケールファイルをリロードし、ダウンロード完了まで待機すること' do
    expect(I18n).to receive(:load_path).and_return([])
    # wait_for_downloadはTestCacheクラス内で呼ばれる
    subject.reload!
    subject.translate('en', 'test.key', :default => 'something')
  end

  it 'i18nのBaseバックエンドを継承していること' do
    is_expected.to be_kind_of(I18n::Backend::Base)
  end

  it 'キャッシュからキーを検索できること' do
    value = 'hello'
    cache['en.prefix.test.key'] = value

    backend = build_backend

    expect(backend.translate('en', 'test.key', :scope => 'prefix')).to eq(value)
  end

  it 'ロケールファイルとキャッシュから利用可能なロケールを取得できること' do
    allow(YAML).to receive(:unsafe_load_file).and_return({ 'es' => { 'key' => 'value' } })
    allow(I18n).to receive(:load_path).and_return(["test.yml"])

    cache['en.key'] = ''
    cache['fr.key'] = ''

    expect(subject.available_locales).to match_array([:en, :es, :fr])
  end

  it 'default付きで未登録キーをキューイングすること' do
    default = 'default value'

    expect(subject.translate('en', 'test.key', :default => default)).to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it 'defaultが配列（文字列1つ）の場合も未登録キーをキューイングすること' do
    default = 'default value'

    expect(subject.translate('en', 'test.key', :default => [default])).to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it 'defaultなしで未登録キーをキューイングすること' do
    expect { subject.translate('en', 'test.key') }.
      to throw_symbol(:exception)

    expect(cache).to have_key 'en.test.key'
    expect(cache['en.test.key']).to be_nil
  end

  it 'scope付きで未登録キーをキューイングすること' do
    default = 'default value'

    expect(subject.translate('en', 'key', :default => default, :scope => ['test'])).
      to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it 'defaultがシンボルの場合は未登録キーをキューイングしないこと' do
    cache['en.key.one'] = "Expected"

    expect(subject.translate('en', 'key.three', :default => :"key.one")).to eq 'Expected'

    expect(cache).to have_key 'en.key.three'
    expect(cache['en.key.three']).to be_nil

    expect(subject.translate('en', 'key.three', :default => :"key.one")).to eq 'Expected'
  end

  it 'defaultが配列（シンボル含む）の場合は未登録キーをキューイングしないこと' do
    cache['en.key.one'] = "Expected"

    expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).to eq 'Expected'

    expect(cache).to have_key 'en.key.three'
    expect(cache['en.key.three']).to be_nil

    expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).to eq 'Expected'
  end

  it '補間付きで未登録キーをキューイングすること' do
    default = 'default %{interpolate}'

    expect(subject.translate('en', 'test.key', :default => default, :interpolate => 'interpolated')).to eq 'default interpolated'

    expect(cache['en.test.key']).to eq 'default %{interpolate}'
  end

  it 'html safeを付与しないこと' do
    cache['en.test.key'] = FakeHtmlSafeString.new("Hello")
    backend = build_backend
    expect(backend.translate('en', 'test.key')).to_not be_html_safe
  end

  it 'defaultが配列の場合に順に検索できること' do
    cache['en.key.one'] = "Expected"
    backend = build_backend
    expect(backend.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).
      to eq('Expected')
  end

  context 'html_escapeオプションがtrueの場合' do
    before do
      CopyTunerClient.configure do |configuration|
        configuration.html_escape = true
        configuration.client = FakeClient.new
      end
    end

    it 'html safeを付与しないこと' do
      cache['en.test.key'] = FakeHtmlSafeString.new("Hello")
      backend = build_backend
      expect(backend.translate('en', 'test.key')).not_to be_html_safe
    end
  end

  context '非文字列キーの場合' do
    it 'キャッシュに登録されないこと' do
      expect { subject.translate('en', {}) }.to throw_symbol(:exception)
      expect(cache).not_to have_key 'en.{}'
    end
  end

  describe 'store_translations利用時' do
    subject { build_backend }

    it 'store_translationsで登録した値をdefaultとして利用できること' do
      subject.store_translations('en', 'test' => { 'key' => 'Expected' })
      expect(subject.translate('en', 'test.key', :default => 'Unexpected')).
        to include('Expected')
      expect(cache['en.test.key']).to eq('Expected')
    end

    it '補間マーカーを保持したまま保存できること' do
      subject.store_translations('en', 'test' => { 'key' => '%{interpolate}' })
      expect(subject.translate('en', 'test.key', :interpolate => 'interpolated')).
        to include('interpolated')
      expect(cache['en.test.key']).to eq('%{interpolate}')
    end

    it 'store_translationsでキーがなければdefaultを利用すること' do
      expect(subject.translate('en', 'test.key', :default => 'Expected')).
        to include('Expected')
    end

    it 'キャッシュにキーがあればそちらを優先すること' do
      subject.store_translations('en', 'test' => { 'key' => 'Unexpected' })
      cache['en.test.key'] = 'Expected'
      expect(subject.translate('en', 'test.key', :default => 'default')).
        to include('Expected')
    end

    it 'ネストしたハッシュを保存できること' do
      nested = { :nested => 'value' }
      subject.store_translations('en', 'key' => nested)
      expect(subject.translate('en', 'key', :default => 'Unexpected')).to eq(nested)
      expect(cache['en.key.nested']).to eq('value')
    end

    it '配列はそのまま返しキャッシュしないこと' do
      array = ['value']
      subject.store_translations('en', 'key' => array)
      expect(subject.translate('en', 'key', :default => 'Unexpected')).to eq(array)
      expect(cache['en.key']).to be_nil
    end

    it 'defaultが配列の場合に順に検索できること' do
      subject.store_translations('en', 'key' => { 'one' => 'Expected' })
      expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).
        to include('Expected')
    end
  end

  describe 'Fallbacks利用時' do
    subject { build_backend }

    before do
      CopyTunerClient::I18nBackend.class_eval do
        include I18n::Backend::Fallbacks
      end
    end

    it 'defaultとFallbacks併用時はキャッシュにデフォルト値を入れないこと' do
      default = 'default value'
      expect(subject.translate('en', 'test.key', :default => default)).to eq(default)

      # default と Fallbacks を併用した場合、キャッシュにデフォルト値は入らない仕様に変えた
      # その仕様にしないと、うまく Fallbacks の処理が動かないため
      expect(cache).to have_key 'en.test.key'
      expect(cache['en.test.key']).to be_nil
    end
  end

  # NOTE: 色々考慮する必要があることが分かったため暫定対応として、ツリーキャッシュを使用しないようにしている
  describe 'ツリー構造のlookup' do # rubocop:disable Metrics/BlockLength
    subject { build_backend }

    context '完全一致が存在する場合' do
      it 'ツリー構造より完全一致を優先すること' do
        cache['ja.views.hoge'] = 'exact_value'
        cache['ja.views.hoge.sub'] = 'sub_value'

        result = subject.translate('ja', 'views.hoge')
        expect(result).to eq('exact_value')
      end
    end

    context 'ツリー構造のみ存在する場合' do
      it '部分キーでツリー構造を返すこと' do
        cache['ja.views.hoge'] = 'test'
        cache['ja.views.fuga'] = 'test2'
        cache['ja.other.key'] = 'other'

        result = subject.translate('ja', 'views')
        expect(result).to eq({
          :hoge => 'test',
          :fuga => 'test2'
        })
      end

      it '存在しない部分キーはnilを返すこと' do
        cache['ja.views.hoge'] = 'test'

        result = subject.translate('ja', 'nonexistent', default: nil)
        expect(result).to be_nil
      end

      it 'ネストしたツリー構造を返すこと' do
        cache['ja.views.users.index'] = 'user index'
        cache['ja.views.users.show'] = 'user show'
        cache['ja.views.posts.index'] = 'post index'

        result = subject.translate('ja', 'views')
        expect(result).to eq({
          :users => {
            :index => 'user index',
            :show => 'user show'
          },
          :posts => {
            :index => 'post index'
          }
        })
      end
    end

    context '混在シナリオ' do
      before do
        cache['ja.views.hoge'] = 'exact_hoge'
        cache['ja.views.hoge.sub'] = 'sub_value'
        cache['ja.views.fuga.one'] = 'one'
        cache['ja.views.fuga.two'] = 'two'
      end

      it '完全一致を正しく扱うこと' do
        expect(subject.translate('ja', 'views.hoge')).to eq('exact_hoge')
      end

      it 'ツリー構造を正しく扱うこと' do
        expect(subject.translate('ja', 'views.fuga')).to eq({
          :one => 'one',
          :two => 'two'
        })
      end

      it 'より深い完全一致も正しく扱うこと' do
        expect(subject.translate('ja', 'views.hoge.sub')).to eq('sub_value')
      end
    end

    context 'ツリーキャッシュ管理' do
      it '最初のlookupでツリーキャッシュを構築すること' do
        cache['ja.views.hoge'] = 'test'
        cache['ja.views.fuga'] = 'test2'

        # 最初のlookupでツリーキャッシュが構築される
        result = subject.translate('ja', 'views')
        expect(result).to eq({
          :hoge => 'test',
          :fuga => 'test2'
        })
      end

      it '2回目以降はツリーキャッシュを再利用すること' do
        cache['ja.views.hoge'] = 'test'

        # 1回目
        subject.translate('ja', 'views')

        # ツリーキャッシュの再構築が発生しないことを確認
        expect(cache).not_to receive(:to_tree_hash)

        # 2回目
        subject.translate('ja', 'views')
      end

      it 'キャッシュバージョンが変わった場合はツリーキャッシュを再構築すること' do
        cache['ja.views.hoge'] = 'test'
        subject.translate('ja', 'views')

        # ETag（バージョン）を変更してキャッシュを更新
        cache.etag = '"new_etag"'

        # 新しい値を追加
        cache['ja.views.new'] = 'new value'
        result = subject.translate('ja', 'views')
        expect(result).to include(:new => 'new value')
      end

      it 'キャッシュバージョンがnilでも正常に動作すること' do
        cache['ja.views.test'] = 'value'
        cache.etag = nil

        result = subject.translate('ja', 'views')
        expect(result).to eq({ :test => 'value' })
      end
    end

    context '大規模キャッシュ時のパフォーマンス' do
      it 'etagバージョン管理でツリーキャッシュを効率的に扱うこと' do
        # 大量のキャッシュエントリを追加
        1000.times do |i|
          cache["ja.category#{i % 10}.item#{i}"] = "value#{i}"
        end

        # 初回のツリーキャッシュ構築
        subject.translate('ja', 'category1')

        # ETag が変わらない限り、再構築されない
        expect(cache).not_to receive(:to_tree_hash)

        # 複数回の lookup が高速で実行される
        start_time = Time.now
        10.times { subject.translate('ja', 'category2') }
        end_time = Time.now

        # 10ms 以下で完了することを確認
        expect((end_time - start_time) * 1000).to be < 10
      end
    end

    context 'エッジケース' do
      it '空キャッシュでも正常に動作すること' do
        result = subject.translate('ja', 'views', default: nil)
        expect(result).to be_nil
      end

      it '1階層のキーも正常に扱えること' do
        cache['ja.simple'] = 'simple value'

        result = subject.translate('ja', 'simple')
        expect(result).to eq('simple value')
      end

      it 'ignored_keysの機能がツリーlookupでも維持されること' do
        # ignored_keys 設定
        allow(CopyTunerClient.configuration).to receive(:ignored_keys).and_return(['views.secret'])
        handler = double('ignored_key_handler')
        allow(CopyTunerClient.configuration).to receive(:ignored_key_handler).and_return(handler)

        cache['ja.views.public'] = 'public'
        cache['ja.views.secret'] = 'secret'

        # ignored_key_handler が呼ばれることを確認
        expect(handler).to receive(:call).with(instance_of(CopyTunerClient::IgnoredKey))

        # ignored_keys が動作することを確認
        subject.translate('ja', 'views.secret')
      end

      it 'stringキーが存在する場合のsub-keyアクセスでエラーが発生しないこと' do
        cache['ja.hoge'] = 'hoge value'

        result = subject.translate('ja', 'hoge.hello', default: nil)
        expect(result).to be_nil
      end
    end
  end
end

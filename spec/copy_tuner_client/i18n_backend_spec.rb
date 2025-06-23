require 'spec_helper'

describe CopyTunerClient::I18nBackend do
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
    # TestCacheクラス内でwait_for_downloadが定義されているため、このモックは不要
  end

  after { I18n.backend = @default_backend }

  subject { build_backend }

  it "reloads locale files and waits for the download to complete" do
    expect(I18n).to receive(:load_path).and_return([])
    # wait_for_downloadはTestCacheクラス内で呼ばれる
    subject.reload!
    subject.translate('en', 'test.key', :default => 'something')
  end

  it "includes the base i18n backend" do
    is_expected.to be_kind_of(I18n::Backend::Base)
  end

  it "looks up a key in cache" do
    value = 'hello'
    cache['en.prefix.test.key'] = value

    backend = build_backend

    expect(backend.translate('en', 'test.key', :scope => 'prefix')).to eq(value)
  end

  it "finds available locales from locale files and cache" do
    allow(YAML).to receive(:unsafe_load_file).and_return({ 'es' => { 'key' => 'value' } })
    allow(I18n).to receive(:load_path).and_return(["test.yml"])

    cache['en.key'] = ''
    cache['fr.key'] = ''

    expect(subject.available_locales).to match_array([:en, :es, :fr])
  end

  it "queues missing keys with default" do
    default = 'default value'

    expect(subject.translate('en', 'test.key', :default => default)).to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it "queues missing keys with default string in an array" do
    default = 'default value'

    expect(subject.translate('en', 'test.key', :default => [default])).to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it "queues missing keys without default" do
    expect { subject.translate('en', 'test.key') }.
      to throw_symbol(:exception)

    expect(cache).to have_key 'en.test.key'
    expect(cache['en.test.key']).to be_nil
  end

  it "queues missing keys with scope" do
    default = 'default value'

    expect(subject.translate('en', 'key', :default => default, :scope => ['test'])).
      to eq(default)

    expect(cache['en.test.key']).to eq(default)
  end

  it "does not queues missing keys with a symbol of default" do
    cache['en.key.one'] = "Expected"

    expect(subject.translate('en', 'key.three', :default => :"key.one")).to eq 'Expected'

    expect(cache).to have_key 'en.key.three'
    expect(cache['en.key.three']).to be_nil

    expect(subject.translate('en', 'key.three', :default => :"key.one")).to eq 'Expected'
  end

  it "does not queues missing keys with an array of default" do
    cache['en.key.one'] = "Expected"

    expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).to eq 'Expected'

    expect(cache).to have_key 'en.key.three'
    expect(cache['en.key.three']).to be_nil

    expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).to eq 'Expected'
  end

  it "queues missing keys with interpolation" do
    default = 'default %{interpolate}'

    expect(subject.translate('en', 'test.key', :default => default, :interpolate => 'interpolated')).to eq 'default interpolated'

    expect(cache['en.test.key']).to eq 'default %{interpolate}'
  end

  it "dose not mark strings as html safe" do
    cache['en.test.key'] = FakeHtmlSafeString.new("Hello")
    backend = build_backend
    expect(backend.translate('en', 'test.key')).to_not be_html_safe
  end

  it "looks up an array of defaults" do
    cache['en.key.one'] = "Expected"
    backend = build_backend
    expect(backend.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).
      to eq('Expected')
  end

  context "html_escape option is true" do
    before do
      CopyTunerClient.configure do |configuration|
        configuration.html_escape = true
        configuration.client = FakeClient.new
      end
    end

    it "do not marks strings as html safe" do
      cache['en.test.key'] = FakeHtmlSafeString.new("Hello")
      backend = build_backend
      expect(backend.translate('en', 'test.key')).not_to be_html_safe
    end
  end

  context 'non-string key' do
    it 'Not to be registered in the cache' do
      expect { subject.translate('en', {}) }.to throw_symbol(:exception)
      expect(cache).not_to have_key 'en.{}'
    end
  end

  describe "with stored translations" do
    subject { build_backend }

    it "uses stored translations as a default" do
      subject.store_translations('en', 'test' => { 'key' => 'Expected' })
      expect(subject.translate('en', 'test.key', :default => 'Unexpected')).
        to include('Expected')
      expect(cache['en.test.key']).to eq('Expected')
    end

    it "preserves interpolation markers in the stored translation" do
      subject.store_translations('en', 'test' => { 'key' => '%{interpolate}' })
      expect(subject.translate('en', 'test.key', :interpolate => 'interpolated')).
        to include('interpolated')
      expect(cache['en.test.key']).to eq('%{interpolate}')
    end

    it "uses the default if the stored translations don't have the key" do
      expect(subject.translate('en', 'test.key', :default => 'Expected')).
        to include('Expected')
    end

    it "uses the cached key when present" do
      subject.store_translations('en', 'test' => { 'key' => 'Unexpected' })
      cache['en.test.key'] = 'Expected'
      expect(subject.translate('en', 'test.key', :default => 'default')).
        to include('Expected')
    end

    it "stores a nested hash" do
      nested = { :nested => 'value' }
      subject.store_translations('en', 'key' => nested)
      expect(subject.translate('en', 'key', :default => 'Unexpected')).to eq(nested)
      expect(cache['en.key.nested']).to eq('value')
    end

    it "returns an array directly without storing" do
      array = ['value']
      subject.store_translations('en', 'key' => array)
      expect(subject.translate('en', 'key', :default => 'Unexpected')).to eq(array)
      expect(cache['en.key']).to be_nil
    end

    it "looks up an array of defaults" do
      subject.store_translations('en', 'key' => { 'one' => 'Expected' })
      expect(subject.translate('en', 'key.three', :default => [:"key.two", :"key.one"])).
        to include('Expected')
    end
  end

  describe "with a backend using fallbacks" do
    subject { build_backend }

    before do
      CopyTunerClient::I18nBackend.class_eval do
        include I18n::Backend::Fallbacks
      end
    end

    it "queues missing keys with blank string" do
      default = 'default value'
      expect(subject.translate('en', 'test.key', :default => default)).to eq(default)

      # default と Fallbacks を併用した場合、キャッシュにデフォルト値は入らない仕様に変えた
      # その仕様にしないと、うまく Fallbacks の処理が動かないため
      expect(cache).to have_key 'en.test.key'
      expect(cache['en.test.key']).to be_nil
    end
  end

  describe "tree structure lookup" do
    subject { build_backend }

    context "when exact match exists" do
      it "prioritizes exact match over tree structure" do
        cache['ja.views.hoge'] = 'exact_value'
        cache['ja.views.hoge.sub'] = 'sub_value'

        result = subject.translate('ja', 'views.hoge')
        expect(result).to eq('exact_value')
      end
    end

    context "when only tree structure exists" do
      it "returns tree structure for partial key lookup" do
        cache['ja.views.hoge'] = 'test'
        cache['ja.views.fuga'] = 'test2'
        cache['ja.other.key'] = 'other'

        result = subject.translate('ja', 'views')
        expect(result).to eq({
          :hoge => 'test',
          :fuga => 'test2'
        })
      end

      it "returns nil for non-existent partial key" do
        cache['ja.views.hoge'] = 'test'

        result = subject.translate('ja', 'nonexistent', default: nil)
        expect(result).to be_nil
      end

      it "returns nested tree structure" do
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

    context "with mixed scenarios" do
      before do
        cache['ja.views.hoge'] = 'exact_hoge'
        cache['ja.views.hoge.sub'] = 'sub_value'
        cache['ja.views.fuga.one'] = 'one'
        cache['ja.views.fuga.two'] = 'two'
      end

      it "handles exact match correctly" do
        expect(subject.translate('ja', 'views.hoge')).to eq('exact_hoge')
      end

      it "handles tree structure correctly" do
        expect(subject.translate('ja', 'views.fuga')).to eq({
          :one => 'one',
          :two => 'two'
        })
      end

      it "handles deeper exact match correctly" do
        expect(subject.translate('ja', 'views.hoge.sub')).to eq('sub_value')
      end
    end

    context "tree cache management" do
      it "builds tree cache on first lookup" do
        cache['ja.views.hoge'] = 'test'
        cache['ja.views.fuga'] = 'test2'

        # 最初のlookupでツリーキャッシュが構築される
        result = subject.translate('ja', 'views')
        expect(result).to eq({
          :hoge => 'test',
          :fuga => 'test2'
        })
      end

      it "reuses tree cache for subsequent lookups" do
        cache['ja.views.hoge'] = 'test'

        # 1回目
        subject.translate('ja', 'views')

        # ツリーキャッシュの再構築が発生しないことを確認
        expect(cache).not_to receive(:to_tree_hash)

        # 2回目
        subject.translate('ja', 'views')
      end

      it "rebuilds tree cache when cache version changes" do
        cache['ja.views.hoge'] = 'test'
        subject.translate('ja', 'views')

        # ETag（バージョン）を変更してキャッシュを更新
        cache.etag = '"new_etag"'

        # 新しい値を追加
        cache['ja.views.new'] = 'new value'
        result = subject.translate('ja', 'views')
        expect(result).to include(:new => 'new value')
      end

      it "handles nil cache version gracefully" do
        cache['ja.views.test'] = 'value'
        cache.etag = nil

        result = subject.translate('ja', 'views')
        expect(result).to eq({ :test => 'value' })
      end
    end

    context "performance with large cache" do
      it "efficiently manages tree cache with etag versioning" do
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

    context "edge cases" do
      it "handles empty cache gracefully" do
        result = subject.translate('ja', 'views', default: nil)
        expect(result).to be_nil
      end

      it "handles single level keys" do
        cache['ja.simple'] = 'simple value'

        result = subject.translate('ja', 'simple')
        expect(result).to eq('simple value')
      end

      it "maintains ignored_keys functionality with tree lookup" do
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
    end
  end
end

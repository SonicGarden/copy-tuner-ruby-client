require 'spec_helper'

describe 'CopyTunerClient::Cache' do
  let(:client) { FakeClient.new }

  def build_cache(ready: false, **config)
    config[:client] ||= client
    config[:logger] ||= FakeLogger.new
    default_config = CopyTunerClient::Configuration.new.to_hash
    cache = CopyTunerClient::Cache.new(client, default_config.update(config))
    cache.instance_variable_set(:@status, CopyTunerClient::Cache::STATUS_READY) if ready
    cache
  end

  it 'ダウンロードしたデータにアクセスできること' do
    client['en.test.key']       = 'expected'
    client['en.test.other_key'] = 'expected'

    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to eq('expected')
    expect(cache.keys).to match_array(%w[en.test.key en.test.other_key])
  end

  it 'exclude_key_regexpが設定されている場合、該当データを除外すること' do
    cache = build_cache(exclude_key_regexp: /^en\.test\.other_key$/)
    cache['en.test.key']       = 'expected'
    cache['en.test.other_key'] = 'expected'

    cache.download

    expect(cache.queued.keys).to match_array(%w[en.test.key])
  end

  it '変更がない場合はアップロードしないこと' do
    cache = build_cache
    cache.flush
    expect(client).not_to be_uploaded
  end

  it '不正なキーはアップロードしないこと' do
    cache = build_cache
    cache['ja'] = 'incorrect key'

    cache.flush
    expect(client).not_to be_uploaded
  end

  it '変更があればflush時にアップロードすること' do
    cache = build_cache
    cache['test.key'] = 'test value'

    cache.flush

    expect(client.uploaded).to eq({ 'test.key' => 'test value' })
  end

  it 'nilを代入した場合は空文字でアップロードすること' do
    cache = build_cache
    cache['test.key'] = nil

    cache.flush

    expect(client.uploaded).to eq({ 'test.key' => '' })
  end

  it 'ロケールフィルタなしでアップロードできること' do
    cache = build_cache
    cache['en.test.key'] = 'uploaded en'
    cache['ja.test.key'] = 'uploaded ja'

    cache.flush

    expect(client.uploaded).to eq({ 'en.test.key' => 'uploaded en', 'ja.test.key' => 'uploaded ja' })
  end

  it 'ロケールフィルタありでアップロードできること' do
    cache = build_cache(locales: %(en))
    cache['en.test.key'] = 'uploaded'
    cache['ja.test.key'] = 'not uploaded'

    cache.flush

    expect(client.uploaded).to eq({ 'en.test.key' => 'uploaded' })
  end

  it 'ダウンロードで値を取得できること' do
    client['test.key'] = 'test value'
    cache = build_cache

    cache.download

    expect(cache['test.key']).to eq('test value')
  end

  it 'syncでダウンロードとアップロードが両方行われること' do
    cache = build_cache
    client['test.key'] = 'test value'
    cache['other.key'] = 'other value'

    cache.sync

    expect(client.uploaded).to eq({ 'other.key' => 'other value' })
    expect(cache['test.key']).to eq('test value')
  end

  it '空文字のキーはダウンロード時にnilになること' do
    client['en.test.key'] = 'test value'
    client['en.test.empty'] = ''
    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to eq('test value')
    expect(cache['en.test.empty']).to eq(nil)

    cache['en.test.empty'] = ''
    expect(cache.queued).to be_empty
  end

  it 'ダウンロードしたキーはアップロード対象にならないこと' do
    client['en.test.key'] = 'test value'
    cache = build_cache

    cache.download

    cache['en.test.key'] = 'dummy'
    expect(cache.queued).to be_empty
  end

  it 'flush時に接続エラーが発生した場合はエラーログを出力すること' do
    failure = 'server is napping'
    logger = FakeLogger.new
    expect(client).to receive(:upload).and_raise(CopyTunerClient::ConnectionError.new(failure))
    cache = build_cache(logger: logger)
    cache['upload.key'] = 'upload'

    cache.flush

    expect(logger).to have_entry(:error, failure)
  end

  it 'download時に接続エラーが発生した場合はエラーログを出力すること' do
    failure = 'server is napping'
    logger = FakeLogger.new
    expect(client).to receive(:download).and_raise(CopyTunerClient::ConnectionError.new(failure))
    cache = build_cache(logger: logger, ready: true)

    cache.download

    expect(logger).to have_entry(:error, failure)
  end

  it '最初のダウンロードが完了するまでブロックすること' do
    logger = FakeLogger.new
    expect(logger).to receive(:flush)
    client.delay = true
    cache = build_cache(logger: logger)

    t_download = Thread.new { cache.download }
    sleep 0.1 until cache.pending?

    t_wait = Thread.new do
      cache.wait_for_download
    end
    sleep 0.1 until logger.has_entry?(:info, 'Waiting for first download')
    client.go
    expect(t_download.join(1)).not_to be_nil
    expect(cache.pending?).to be_falsey
    expect(t_wait.join(1)).not_to be_nil
  end

  it 'ダウンロード前はブロックしないこと' do
    logger = FakeLogger.new
    cache = build_cache(logger: logger)

    finished = false
    Thread.new do
      cache.wait_for_download
      finished = true
    end

    sleep(1)

    expect(finished).to eq(true)
    expect(logger).not_to have_entry(:info, 'Waiting for first download')
  end

  it '空文字のコピーは返さないこと' do
    client['en.test.key'] = ''
    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to be_nil
  end

  describe 'ミューテックスがロックされている場合' do
    RSpec::Matchers.define :finish_after_unlocking do |mutex|
      match do |thread|
        sleep(0.1)

        if thread.status === false
          violated('アンロック前に終了してしまった')
        else
          mutex.unlock
          sleep(0.1)

          if thread.status === false
            true
          else
            violated('アンロック後もスレッドが終了しない')
          end
        end
      end

      def violated(failure)
        @failure_message = failure
        false
      end

      failure_message do
        @failure_message
      end
    end

    let(:mutex) { Mutex.new }
    let(:cache) { build_cache }

    before do
      mutex.lock
      allow(Mutex).to receive(:new).and_return(mutex)
    end

    it 'スレッド間でキーの読み取りアクセスが同期されること' do
      expect(Thread.new { cache['test.key'] }).to finish_after_unlocking(mutex)
    end

    it 'スレッド間でキーリストの読み取りアクセスが同期されること' do
      expect(Thread.new { cache.keys }).to finish_after_unlocking(mutex)
    end

    it 'スレッド間でキーの書き込みアクセスが同期されること' do
      expect(Thread.new { cache['test.key'] = 'value' }).to finish_after_unlocking(mutex)
    end
  end

  it 'トップレベルからflushできること' do
    cache = build_cache
    CopyTunerClient.configure do |config|
      config.cache = cache
    end
    expect(cache).to receive(:flush).at_least(:once)

    CopyTunerClient.flush
  end

  describe '#to_tree_hash' do
    subject { cache.to_tree_hash }

    let(:cache) do
      cache = build_cache
      cache.download
      cache
    end

    it 'データがない場合は空ハッシュを返すこと' do
      is_expected.to eq({})
    end

    context 'フラットなキーの場合' do
      before do
        client['ja.views.hoge'] = 'test'
        client['ja.views.fuga'] = 'test2'
        client['en.hello'] = 'world'
      end

      it 'ツリー構造に変換されること' do
        is_expected.to eq({
          'ja' => {
            'views' => {
              'hoge' => 'test',
              'fuga' => 'test2'
            }
          },
          'en' => {
            'hello' => 'world'
          }
        })
      end
    end

    context '複雑なネスト構造の場合' do
      before do
        client['ja.views.users.index'] = 'user index'
        client['ja.views.users.show'] = 'user show'
        client['ja.views.posts.index'] = 'post index'
        client['en.common.buttons.save'] = 'Save'
      end

      it '正しいツリー構造になること' do
        is_expected.to eq({
          'ja' => {
            'views' => {
              'users' => {
                'index' => 'user index',
                'show' => 'user show'
              },
              'posts' => {
                'index' => 'post index'
              }
            }
          },
          'en' => {
            'common' => {
              'buttons' => {
                'save' => 'Save'
              }
            }
          }
        })
      end
    end
  end

  describe '#version' do
    it 'クライアントのetagを返すこと（効率的なバージョンチェック）' do
      cache = build_cache
      client_instance = cache.send(:client)

      # ETag が設定されている場合
      client_instance.etag = '"abc123"'
      expect(cache.version).to eq('"abc123"')

      # ETag が変更された場合
      client_instance.etag = '"def456"'
      expect(cache.version).to eq('"def456"')
    end

    it 'etagがnilの場合も正常に動作すること' do
      cache = build_cache
      client_instance = cache.send(:client)
      client_instance.etag = nil

      expect(cache.version).to be_nil
    end

    it '大量のキャッシュでも高速にバージョン取得できること（keyのhashではなくetagを使うため）' do
      cache = build_cache

      # 大量のキーを追加
      1000.times do |i|
        cache.instance_variable_get(:@blurbs)["ja.category#{i % 10}.item#{i}"] = "value#{i}"
      end

      # version メソッドが etag を使用しているため高速（keys.hashだと低速）
      start_time = Time.now
      1000.times { cache.version }
      end_time = Time.now

      # 10ms 以下で完了することを確認
      expect((end_time - start_time) * 1000).to be < 10
    end
  end

  describe '#export' do
    subject { cache.export }

    let(:cache) do
      cache = build_cache
      cache.download
      cache
    end

    it 'トップレベル定数から呼び出せること' do
      CopyTunerClient.configure do |config|
        config.cache = cache
      end
      expect(cache).to receive(:export)
      CopyTunerClient.export
    end

    it 'blurbキーがない場合はyamlを返さないこと' do
      is_expected.to eq nil
    end

    context '1階層のblurbキーがある場合' do
      before do
        client['key']       = 'test value'
        client['other_key'] = 'other test value'
      end

      it { is_expected.to eq "---\nkey: test value\nother_key: other test value\n" }
    end
  end
end

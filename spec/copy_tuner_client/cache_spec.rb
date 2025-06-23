require 'spec_helper'

describe CopyTunerClient::Cache do
  let(:client) { FakeClient.new }

  def build_cache(ready: false, **config)
    config[:client] ||= client
    config[:logger] ||= FakeLogger.new
    default_config = CopyTunerClient::Configuration.new.to_hash
    cache = CopyTunerClient::Cache.new(client, default_config.update(config))
    cache.instance_variable_set(:@status, CopyTunerClient::Cache::STATUS_READY) if ready
    cache
  end

  it 'provides access to downloaded data' do
    client['en.test.key']       = 'expected'
    client['en.test.other_key'] = 'expected'

    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to eq('expected')
    expect(cache.keys).to match_array(%w[en.test.key en.test.other_key])
  end

  it 'exclude data if exclude_key_regexp is set' do
    cache = build_cache(exclude_key_regexp: /^en\.test\.other_key$/)
    cache['en.test.key']       = 'expected'
    cache['en.test.other_key'] = 'expected'

    cache.download

    expect(cache.queued.keys).to match_array(%w[en.test.key])
  end

  it "doesn't upload without changes" do
    cache = build_cache
    cache.flush
    expect(client).not_to be_uploaded
  end

  it "Don't upload incorrect key" do
    cache = build_cache
    cache['ja'] = 'incorrect key'

    cache.flush
    expect(client).not_to be_uploaded
  end

  it 'uploads changes when flushed' do
    cache = build_cache
    cache['test.key'] = 'test value'

    cache.flush

    expect(client.uploaded).to eq({ 'test.key' => 'test value' })
  end

  it 'uploads empties when nil is assigned' do
    cache = build_cache
    cache['test.key'] = nil

    cache.flush

    expect(client.uploaded).to eq({ 'test.key' => '' })
  end

  it 'upload without locale filter' do
    cache = build_cache
    cache['en.test.key'] = 'uploaded en'
    cache['ja.test.key'] = 'uploaded ja'

    cache.flush

    expect(client.uploaded).to eq({ 'en.test.key' => 'uploaded en', 'ja.test.key' => 'uploaded ja' })
  end

  it 'upload with locale filter' do
    cache = build_cache(locales: %(en))
    cache['en.test.key'] = 'uploaded'
    cache['ja.test.key'] = 'not uploaded'

    cache.flush

    expect(client.uploaded).to eq({ 'en.test.key' => 'uploaded' })
  end

  it 'downloads changes' do
    client['test.key'] = 'test value'
    cache = build_cache

    cache.download

    expect(cache['test.key']).to eq('test value')
  end

  it 'downloads and uploads when synced' do
    cache = build_cache
    client['test.key'] = 'test value'
    cache['other.key'] = 'other value'

    cache.sync

    expect(client.uploaded).to eq({ 'other.key' => 'other value' })
    expect(cache['test.key']).to eq('test value')
  end

  it 'download included empty keys' do
    client['en.test.key'] = 'test value'
    client['en.test.empty'] = ''
    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to eq('test value')
    expect(cache['en.test.empty']).to eq(nil)

    cache['en.test.empty'] = ''
    expect(cache.queued).to be_empty
  end

  it 'Do not upload downloaded keys' do
    client['en.test.key'] = 'test value'
    cache = build_cache

    cache.download

    cache['en.test.key'] = 'dummy'
    expect(cache.queued).to be_empty
  end

  it 'handles connection errors when flushing' do
    failure = 'server is napping'
    logger = FakeLogger.new
    expect(client).to receive(:upload).and_raise(CopyTunerClient::ConnectionError.new(failure))
    cache = build_cache(logger: logger)
    cache['upload.key'] = 'upload'

    cache.flush

    expect(logger).to have_entry(:error, failure)
  end

  it 'handles connection errors when downloading' do
    failure = 'server is napping'
    logger = FakeLogger.new
    expect(client).to receive(:download).and_raise(CopyTunerClient::ConnectionError.new(failure))
    cache = build_cache(logger: logger, ready: true)

    cache.download

    expect(logger).to have_entry(:error, failure)
  end

  it 'blocks until the first download is complete' do
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

  it "doesn't block before downloading" do
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

  it "doesn't return blank copy" do
    client['en.test.key'] = ''
    cache = build_cache

    cache.download

    expect(cache['en.test.key']).to be_nil
  end

  describe 'given locked mutex' do
    RSpec::Matchers.define :finish_after_unlocking do |mutex|
      match do |thread|
        sleep(0.1)

        if thread.status === false
          violated('finished before unlocking')
        else
          mutex.unlock
          sleep(0.1)

          if thread.status === false
            true
          else
            violated('still running after unlocking')
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

    it 'synchronizes read access to keys between threads' do
      expect(Thread.new { cache['test.key'] }).to finish_after_unlocking(mutex)
    end

    it 'synchronizes read access to the key list between threads' do
      expect(Thread.new { cache.keys }).to finish_after_unlocking(mutex)
    end

    it 'synchronizes write access to keys between threads' do
      expect(Thread.new { cache['test.key'] = 'value' }).to finish_after_unlocking(mutex)
    end
  end

  it 'flushes from the top level' do
    cache = build_cache
    CopyTunerClient.configure do |config|
      config.cache = cache
    end
    expect(cache).to receive(:flush).at_least(:once)

    CopyTunerClient.flush
  end

  describe "#to_tree_hash" do
    subject { cache.to_tree_hash }

    let(:cache) do
      cache = build_cache
      cache.download
      cache
    end

    it "returns empty hash when no blurbs" do
      is_expected.to eq({})
    end

    context "with flat keys" do
      before do
        client['ja.views.hoge'] = 'test'
        client['ja.views.fuga'] = 'test2'
        client['en.hello'] = 'world'
      end

      it "converts to tree structure" do
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

    context "with complex nested structure" do
      before do
        client['ja.views.users.index'] = 'user index'
        client['ja.views.users.show'] = 'user show'
        client['ja.views.posts.index'] = 'post index'
        client['en.common.buttons.save'] = 'Save'
      end

      it "builds proper tree structure" do
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

  describe "#version" do
    it "returns client etag for efficient version checking" do
      cache = build_cache
      client_instance = cache.send(:client)

      # ETag が設定されている場合
      client_instance.etag = '"abc123"'
      expect(cache.version).to eq('"abc123"')

      # ETag が変更された場合
      client_instance.etag = '"def456"'
      expect(cache.version).to eq('"def456"')
    end

    it "handles nil etag gracefully" do
      cache = build_cache
      client_instance = cache.send(:client)
      client_instance.etag = nil

      expect(cache.version).to be_nil
    end

    it "is more efficient than key-based hashing for large caches" do
      cache = build_cache

      # 大量のキーを追加
      1000.times do |i|
        cache.instance_variable_get(:@blurbs)["ja.category#{i % 10}.item#{i}"] = "value#{i}"
      end

      # version メソッドが etag を使用しているため高速
      start_time = Time.now
      100.times { cache.version }
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

    it 'can be invoked from the top-level constant' do
      CopyTunerClient.configure do |config|
        config.cache = cache
      end
      expect(cache).to receive(:export)
      CopyTunerClient.export
    end

    it 'returns no yaml with no blurb keys' do
      is_expected.to eq nil
    end

    context 'with single-level blurb keys' do
      before do
        client['key']       = 'test value'
        client['other_key'] = 'other test value'
      end

      it { is_expected.to eq "---\nkey: test value\nother_key: other test value\n" }
    end
  end
end

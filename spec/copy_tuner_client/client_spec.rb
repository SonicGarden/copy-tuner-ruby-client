require 'spec_helper'

describe 'CopyTunerClient' do
  let(:download_cache_dir) { Pathname.new(Dir.mktmpdir('copy_tuner_client')) }

  after do
    FileUtils.rm_rf(download_cache_dir)
  end

  def build_client(config = {})
    config[:logger] ||= FakeLogger.new
    config[:download_cache_dir] = download_cache_dir
    default_config = CopyTunerClient::Configuration.new.to_hash
    default_config[:s3_host] = 'copy-tuner.com'
    client = CopyTunerClient::Client.new(default_config.update(config))
    client
  end

  def add_project
    api_key = 'xyz123'
    FakeCopyTunerApp.add_project(api_key)
  end

  def build_client_with_project(config = {})
    project = add_project
    config[:api_key] = project.api_key
    build_client(config)
  end

  describe 'コネクションのオープン' do
    let(:config) { CopyTunerClient::Configuration.new }
    let(:http) { Net::HTTP.new(config.host, config.port) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
    end

    it '接続時のタイムアウトが設定されていること' do
      project = add_project
      client = build_client(:api_key => project.api_key, :http_open_timeout => 4)
      client.download { |ignore| }
      expect(http.open_timeout).to eq(4)
    end

    it '読み込み時のタイムアウトが設定されていること' do
      project = add_project
      client = build_client(:api_key => project.api_key, :http_read_timeout => 4)
      client.download { |ignore| }
      expect(http.read_timeout).to eq(4)
    end

    it 'secureがtrueの場合はSSL検証付きで接続すること' do
      project = add_project
      client = build_client(:api_key => project.api_key, :secure => true)
      client.download { |ignore| }
      expect(http.use_ssl?).to eq(true)
      expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'secureがfalseの場合はSSLを使用しないこと' do
      project = add_project
      client = build_client(:api_key => project.api_key, :secure => false)
      client.download { |ignore| }
      expect(http.use_ssl?).to eq(false)
    end

    it 'HTTPエラーをConnectionErrorでラップすること' do
      errors = [
        Timeout::Error.new,
        Errno::EINVAL.new,
        Errno::ECONNRESET.new,
        EOFError.new,
        Net::HTTPBadResponse.new,
        Net::HTTPHeaderSyntaxError.new,
        Net::ProtocolError.new,
        SocketError.new,
        OpenSSL::SSL::SSLError.new,
        Errno::ECONNREFUSED.new
      ]

      errors.each do |original_error|
        allow(http).to receive(:request).and_raise(original_error)
        client = build_client_with_project
        expect { client.download { |ignore| } }.
          to raise_error(CopyTunerClient::ConnectionError) { |error|
            expect(error.message).
              to eq("#{original_error.class.name}: #{original_error.message}")
          }
      end
    end

    it 'ダウンロード時に500エラーが発生した場合はConnectionErrorになること' do
      client = build_client(:api_key => 'raise_error')
      expect { client.download { |ignore| } }.
        to raise_error(CopyTunerClient::ConnectionError)
    end

    it 'アップロード時に500エラーが発生した場合はConnectionErrorになること' do
      client = build_client(:api_key => 'raise_error')
      expect { client.upload({}) }.to raise_error(CopyTunerClient::ConnectionError)
    end

    it 'ダウンロード時に404エラーが発生した場合はInvalidApiKeyになること' do
      client = build_client(:api_key => 'bogus')
      expect { client.download { |ignore| } }.
        to raise_error(CopyTunerClient::InvalidApiKey)
    end

    it 'アップロード時に404エラーが発生した場合はInvalidApiKeyになること' do
      client = build_client(:api_key => 'bogus')
      expect { client.upload({}) }.to raise_error(CopyTunerClient::InvalidApiKey)
    end
  end

  it '既存プロジェクトのpublishedなblurbをダウンロードできること' do
    project = add_project
    project.update({
      'draft' => {
        'key.one'   => 'unexpected one',
        'key.three' => 'unexpected three'
      },
      'published' => {
        'key.one' => 'expected one',
        'key.two' => 'expected two'
      }
    })
    client = build_client(:api_key => project.api_key, :public => true)
    blurbs = nil

    client.download { |yielded| blurbs = yielded }

    expect(blurbs).to eq({
      'key.one' => 'expected one',
      'key.two' => 'expected two'
    })
  end

  it 'ダウンロードを実行したことをログに出力すること' do
    logger = FakeLogger.new
    client = build_client_with_project(:logger => logger)
    client.download { |ignore| }
    expect(logger).to have_entry(:info, 'Downloaded translations')
  end

  it '既存プロジェクトのdraftなblurbをダウンロードできること' do
    project = add_project
    project.update({
      'draft' => {
        'key.one' => 'expected one',
        'key.two' => 'expected two'
      },
      'published' => {
        'key.one'   => 'unexpected one',
        'key.three' => 'unexpected three'
      }
    })
    client = build_client(:api_key => project.api_key, :public => false)
    blurbs = nil

    client.download { |yielded| blurbs = yielded }

    expect(blurbs).to eq({
      'key.one' => 'expected one',
      'key.two' => 'expected two'
    })
  end

  it '304レスポンス時は2回目以降yieldされないこと' do
    project = add_project
    project.update('draft' => { 'key.one' => "expected one" })
    logger = FakeLogger.new
    client = build_client(:api_key => project.api_key,
                          :public  => false,
                          :logger  => logger)
    yields = 0

    2.times do
      client.download { |ignore| yields += 1 }
    end

    expect(yields).to eq(1)
    expect(logger).to have_entry(:info, "No new translations")
  end

  it '既存プロジェクトに存在しないblurbはアップロードされること' do
    project = add_project

    blurbs = {
      'key.one' => 'expected one',
      'key.two' => 'expected two'
    }

    client = build_client(:api_key => project.api_key, :public => true)
    client.upload(blurbs)

    expect(project.reload.draft).to eq(blurbs)
  end

  it 'アップロードを実行したことをログに出力すること' do
    logger = FakeLogger.new
    client = build_client_with_project(:logger => logger)
    client.upload({})
    expect(logger).to have_entry(:info, "Uploaded missing translations")
  end

  it 'トップレベル定数からdeployできること' do
    client = build_client
    allow(client).to receive(:download)
    CopyTunerClient.configure do |config|
      config.client = client
    end
    expect(client).to receive(:deploy)

    CopyTunerClient.deploy
  end

  it 'deployが実行できること' do
    project = add_project
    project.update({
      'draft' => {
        'key.one' => "expected one",
        'key.two' => "expected two"
      },
      'published' => {
        'key.one'   => "unexpected one",
        'key.two'   => "expected one",
      }
    })
    logger = FakeLogger.new
    client = build_client(:api_key => project.api_key, :logger => logger)

    client.deploy

    expect(project.reload.published).to eq({
      'key.one'   => "expected one",
      'key.two'   => "expected two"
    })
    expect(logger).to have_entry(:info, "Deployed")
  end

  it 'deploy時にエラーが発生した場合は例外が発生すること' do
    expect { build_client.deploy }.to raise_error(CopyTunerClient::InvalidApiKey)
  end

  describe '#etag' do
    it 'etagが読み取り可能な属性として公開されていること' do
      client = build_client
      expect(client).to respond_to(:etag)
    end

    it '初期状態ではetagがnilであること' do
      client = build_client
      expect(client.etag).to be_nil
    end

    it 'ダウンロード成功時にetagが更新されること' do
      project = add_project
      client = build_client(:api_key => project.api_key)

      # モックでETagを設定
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return('{}')
      allow(response).to receive(:[]).with('ETag').and_return('"abc123"')

      http = double('http')
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:ca_file=)
      allow(http).to receive(:request).and_return(response)

      client.download { |blurbs| }
      expect(client.etag).to eq('"abc123"')
    end
  end
end

require 'spec_helper'

describe CopyTunerClient::Configuration do
  RSpec::Matchers.define :have_config_option do |option|
    match do |config|
      expect(config).to respond_to(option)

      expect(config.send(option)).to eq(@default) if instance_variables.include?(:@default)

      if @overridable
        value = 'a value'
        config.send(:"#{option}=", value)
        expect(config.send(option)).to eq(value)
      end
    end

    chain :default do |default|
      @default = default
    end

    chain :overridable do
      @overridable = true
    end
  end

  it { is_expected.to have_config_option(:proxy_host).overridable.default(nil) }
  it { is_expected.to have_config_option(:proxy_port).overridable.default(nil) }
  it { is_expected.to have_config_option(:proxy_user).overridable.default(nil) }
  it { is_expected.to have_config_option(:proxy_pass).overridable.default(nil) }
  it { is_expected.to have_config_option(:environment_name).overridable.default(nil) }
  it { is_expected.to have_config_option(:client_version).overridable.default(CopyTunerClient::VERSION) }
  it { is_expected.to have_config_option(:client_name).overridable.default('CopyTuner Client') }
  it { is_expected.to have_config_option(:client_url).overridable.default('https://rubygems.org/gems/copy_tuner_client') }
  it { is_expected.to have_config_option(:secure).overridable.default(true) }
  it { is_expected.to have_config_option(:host).overridable.default('copy-tuner.com') }
  it { is_expected.to have_config_option(:http_open_timeout).overridable.default(5) }
  it { is_expected.to have_config_option(:http_read_timeout).overridable.default(5) }
  it { is_expected.to have_config_option(:port).overridable }
  it { is_expected.to have_config_option(:development_environments).overridable }
  it { is_expected.to have_config_option(:api_key).overridable }
  it { is_expected.to have_config_option(:polling_delay).overridable.default(300) }
  it { is_expected.to have_config_option(:framework).overridable }
  it { is_expected.to have_config_option(:middleware).overridable }
  it { is_expected.to have_config_option(:client).overridable }
  it { is_expected.to have_config_option(:cache).overridable }
  it { is_expected.to have_config_option(:local_first_key_regexp).overridable.default(nil) }

  it 'provides default values for secure connections' do
    config = CopyTunerClient::Configuration.new
    config.secure = true
    expect(config.port).to eq(443)
    expect(config.protocol).to eq('https')
  end

  it 'provides default values for insecure connections' do
    config = CopyTunerClient::Configuration.new
    config.secure = false
    expect(config.port).to eq(80)
    expect(config.protocol).to eq('http')
  end

  it 'does not cache inferred ports' do
    config = CopyTunerClient::Configuration.new
    config.secure = false
    config.port
    config.secure = true
    expect(config.port).to eq(443)
  end

  it 'acts like a hash' do
    config = CopyTunerClient::Configuration.new
    hash = config.to_hash

    %i[
      api_key environment_name host http_open_timeout
      http_read_timeout client_name client_url client_version port
      protocol proxy_host proxy_pass proxy_port proxy_user secure
      development_environments logger framework ca_file
    ].each do |option|
      expect(hash[option]).to eq(config[option])
    end

    expect(hash[:public]).to eq(config.public?)
  end

  it 'is mergable' do
    config = CopyTunerClient::Configuration.new
    hash = config.to_hash
    expect(config.merge(key: 'value')).to eq(hash.merge(key: 'value'))
  end

  it 'uses development and staging as development environments by default' do
    config = CopyTunerClient::Configuration.new
    expect(config.development_environments).to match_array(%w[development staging])
  end

  it 'uses test and cucumber as test environments by default' do
    config = CopyTunerClient::Configuration.new
    expect(config.test_environments).to match_array(%w[test cucumber])
  end

  it 'is test in a test environment' do
    config = CopyTunerClient::Configuration.new
    config.test_environments = %w[test]
    config.environment_name = 'test'
    expect(config).to be_test
  end

  it 'is public in a public environment' do
    config = CopyTunerClient::Configuration.new
    config.development_environments = %w[development]
    config.environment_name = 'production'
    expect(config).to be_public
    expect(config).not_to be_development
  end

  it 'is development in a development environment' do
    config = CopyTunerClient::Configuration.new
    config.development_environments = %w[staging]
    config.environment_name = 'staging'
    expect(config).to be_development
    expect(config).not_to be_public
  end

  it 'is public without an environment name' do
    config = CopyTunerClient::Configuration.new
    expect(config).to be_public
  end

  it 'yields and save a configuration when configuring' do
    yielded_configuration = nil

    CopyTunerClient.configure(false) do |config|
      yielded_configuration = config
    end

    expect(yielded_configuration).to be_a(CopyTunerClient::Configuration)
    expect(CopyTunerClient.configuration).to eq(yielded_configuration)
  end

  it 'does not apply the configuration when asked not to' do
    logger = FakeLogger.new
    CopyTunerClient.configure(false) { |config| config.logger = logger }
    expect(CopyTunerClient.configuration).not_to be_applied
    expect(logger.entries[:info]).to be_empty
  end

  it 'does not remove existing config options when configuring twice' do
    first_config = nil

    CopyTunerClient.configure(false) do |config|
      first_config = config
    end

    CopyTunerClient.configure(false) do |config|
      expect(config).to eq(first_config)
    end
  end

  it 'starts out unapplied' do
    expect(CopyTunerClient::Configuration.new).not_to be_applied
  end

  it 'logs to $stdout by default' do
    logger = FakeLogger.new
    expect(Logger).to receive(:new).with($stdout).and_return(logger)
    config = CopyTunerClient::Configuration.new
    expect(config.logger.original_logger).to eq(logger)
  end

  it 'generates environment info without a framework' do
    subject.environment_name = 'production'
    expect(subject.environment_info).to eq("[Ruby: #{RUBY_VERSION}] [Env: production]")
  end

  it 'generates environment info with a framework' do
    subject.environment_name = 'production'
    subject.framework = 'Sinatra: 1.0.0'
    expect(subject.environment_info)
      .to eq("[Ruby: #{RUBY_VERSION}] [Sinatra: 1.0.0] [Env: production]")
  end

  it 'prefixes log entries' do
    logger = FakeLogger.new
    config = CopyTunerClient::Configuration.new

    config.logger = logger

    prefixed_logger = config.logger
    expect(prefixed_logger).to be_a(CopyTunerClient::PrefixedLogger)
    expect(prefixed_logger.original_logger).to eq(logger)
  end

  describe '#local_first_key?' do
    let(:config) { CopyTunerClient::Configuration.new }

    it 'returns false when local_first_key_regexp is nil (default)' do
      expect(config.local_first_key?('views.foo.bar')).to eq false
    end

    context 'when local_first_key_regexp is set' do
      before { config.local_first_key_regexp = /\Aviews\./ }

      it 'returns true for a matching key' do
        expect(config.local_first_key?('views.foo.bar')).to eq true
      end

      it 'returns false for a non-matching key' do
        expect(config.local_first_key?('models.foo.bar')).to eq false
      end

      it 'returns false for a nil key' do
        expect(config.local_first_key?(nil)).to eq false
      end

      it 'coerces a Symbol key before matching' do
        expect(config.local_first_key?(:'views.foo')).to eq true
      end
    end

    # NOTE: Rails 標準の number.*.format 配下は precision 等の非文字列値を含み CopyTuner 経由だと壊れるため、
    # ユーザー設定の有無によらず常にローカル優先（組み込み判定）になる
    context 'with built-in Rails number format keys' do
      it 'returns true for built-in number format keys even when local_first_key_regexp is nil' do
        expect(config.local_first_key?('number.format')).to eq true
        expect(config.local_first_key?('number.currency.format')).to eq true
        expect(config.local_first_key?('number.currency.format.precision')).to eq true
        expect(config.local_first_key?('number.percentage.format')).to eq true
        expect(config.local_first_key?('number.human.format.significant')).to eq true
      end

      it 'returns false for app-defined number keys (not Rails format subtrees)' do
        expect(config.local_first_key?('number.gift_amount')).to eq false
        expect(config.local_first_key?('number.my_currency.unit')).to eq false
      end

      it 'returns false for string-only number subtrees and non-number keys' do
        expect(config.local_first_key?('number.human.storage_units.units.byte.one')).to eq false
        expect(config.local_first_key?('date.formats.default')).to eq false
        expect(config.local_first_key?('time.formats.short')).to eq false
        expect(config.local_first_key?('datetime.distance_in_words.x')).to eq false
        expect(config.local_first_key?('views.foo')).to eq false
        expect(config.local_first_key?('numbers.foo')).to eq false
      end

      it 'keeps protecting built-in keys without breaking a user-set regexp' do
        config.local_first_key_regexp = /\Aviews\./

        expect(config.local_first_key?('number.currency.format')).to eq true
        expect(config.local_first_key?('views.foo')).to eq true
        expect(config.local_first_key?('models.foo')).to eq false
      end
    end
  end

  describe 'project_id の必須化' do
    let(:config) do
      config = CopyTunerClient::Configuration.new
      config.api_key = 'abc123'
      config
    end

    it 'project_id が未設定のとき apply が ArgumentError を出すこと' do
      expect { config.apply }.to raise_error(ArgumentError, 'project_id is required')
    end

    it 'project_id が未設定のとき project_url が ArgumentError を出すこと' do
      expect { config.project_url }.to raise_error(ArgumentError, 'project_id is required')
    end

    it 'project_id を設定すると project_url がそれを使った URL を返すこと' do
      config.project_id = 77
      expect(config.project_url).to include('/projects/77')
    end
  end
end

shared_context 'stubbed configuration' do
  subject { CopyTunerClient::Configuration.new }

  let(:backend) { double('i18n-backend') }
  let(:cache) { double('cache', download: 'download') }
  let(:client) { double('client') }
  let(:logger) { FakeLogger.new }
  let(:poller) { double('poller') }
  let(:process_guard) { double('process_guard', start: nil) }

  before do
    allow(CopyTunerClient::I18nBackend).to receive(:new).and_return(backend)
    allow(CopyTunerClient::Client).to receive(:new).and_return(client)
    allow(CopyTunerClient::Cache).to receive(:new).and_return(cache)
    allow(CopyTunerClient::Poller).to receive(:new).and_return(poller)
    allow(CopyTunerClient::ProcessGuard).to receive(:new).and_return(process_guard)
    subject.logger = logger
    # NOTE: apply は project_id 必須になったため、未設定だと raise する。applied 系テストは
    #       project_id 自体を検証しないので適当な値を補っておく
    subject.project_id ||= 1
    apply
  end
end

shared_examples_for 'applied configuration' do
  include_context 'stubbed configuration'

  it { is_expected.to be_applied }

  it 'builds and assigns an I18n backend' do
    expect(CopyTunerClient::I18nBackend).to have_received(:new).with(cache)
    expect(I18n.backend).to eq(backend)
  end

  it 'builds and assigns a poller' do
    expect(CopyTunerClient::Poller).to have_received(:new).with(cache, subject.to_hash)
  end

  it 'builds a process guard' do
    expect(CopyTunerClient::ProcessGuard).to have_received(:new)
      .with(cache, poller, subject.to_hash)
  end

  it 'logs that it is ready' do
    expect(logger).to have_entry(:info, "Client #{CopyTunerClient::VERSION} ready")
  end

  it 'logs environment info' do
    expect(logger).to have_entry(:info, "Environment Info: #{subject.environment_info}")
  end
end

describe CopyTunerClient::Configuration, 'applied when testing' do
  it_behaves_like 'applied configuration' do
    it 'does not start the process guard' do
      expect(process_guard).not_to receive(:start)
    end
  end

  def apply
    subject.environment_name = 'test'
    subject.apply
  end
end

describe CopyTunerClient::Configuration, 'applied when not testing' do
  it_behaves_like 'applied configuration' do
    it 'starts the process guard' do
      expect(process_guard).to have_received(:start)
    end
  end

  def apply
    subject.environment_name = 'development'
    subject.apply
  end
end

describe CopyTunerClient::Configuration, 'applied when developing with middleware' do
  it_behaves_like 'applied configuration' do
    it 'adds the sync middleware' do
      expect(middleware).to include(CopyTunerClient::RequestSync)
    end
  end

  let(:middleware) { MiddlewareStack.new }

  def apply
    subject.middleware = middleware
    subject.environment_name = 'development'
    subject.apply
  end
end

describe CopyTunerClient::Configuration, 'applied when developing without middleware' do
  it_behaves_like 'applied configuration'

  def apply
    subject.middleware = nil
    subject.environment_name = 'development'
    subject.apply
  end
end

describe CopyTunerClient::Configuration, 'applied with middleware when not developing' do
  let(:middleware) { MiddlewareStack.new }

  it_behaves_like 'applied configuration'

  def apply
    subject.middleware = middleware
    subject.environment_name = 'test'
    subject.apply
  end

  it 'does not add the sync middleware' do
    expect(middleware).not_to include(CopyTunerClient::RequestSync)
  end
end

describe CopyTunerClient::Configuration, 'applied without locale filter' do
  include_context 'stubbed configuration'

  def apply
    subject.apply
  end

  it 'has locales [:en]' do
    expect(subject.locales).to eq [:en]
  end
end

describe CopyTunerClient::Configuration, 'applied with locale filter' do
  include_context 'stubbed configuration'

  def apply
    subject.locales = %i[en ja]
    subject.apply
  end

  it 'has locales %i(en ja)' do
    expect(subject.locales).to eq %i[en ja]
  end
end

describe CopyTunerClient::Configuration, 'applied with Rails i18n config' do
  let!(:rails_defined) { Object.const_defined?(:Rails) }

  def self.with_config(i18n_options)
    before do
      Object.const_set :Rails, Module.new unless rails_defined
      i18n = double('i18n', i18n_options)
      allow(Rails).to receive_message_chain(:application, :config, :i18n) { i18n }
    end

    after do
      Object.send(:remove_const, :Rails) unless rails_defined
    end
  end

  def apply
    subject.apply
  end

  context 'with available_locales' do
    with_config(available_locales: %i[en ja])
    include_context 'stubbed configuration'

    it 'has locales %i(en ja)' do
      expect(subject.locales).to eq %i[en ja]
    end
  end

  context 'with default_locale' do
    with_config(available_locales: %i[ja])
    include_context 'stubbed configuration'

    it 'has locales %i(ja)' do
      expect(subject.locales).to eq %i[ja]
    end
  end
end

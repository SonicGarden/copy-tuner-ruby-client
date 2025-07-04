require 'logger'
require 'copy_tuner_client/i18n_backend'
require 'copy_tuner_client/client'
require 'copy_tuner_client/cache'
require 'copy_tuner_client/process_guard'
require 'copy_tuner_client/poller'
require 'copy_tuner_client/prefixed_logger'
require 'copy_tuner_client/request_sync'
require 'copy_tuner_client/copyray_middleware'

module CopyTunerClient
  # Used to set up and modify settings for the client.
  class Configuration
    # These options will be present in the Hash returned by {#to_hash}.
    OPTIONS = %i[api_key development_environments environment_name host
                 http_open_timeout http_read_timeout client_name client_url
                 client_version port protocol proxy_host proxy_pass
                 proxy_port proxy_user secure polling_delay sync_interval
                 sync_interval_staging sync_ignore_path_regex logger
                 framework middleware disable_middleware disable_test_translation
                 ca_file exclude_key_regexp s3_host locales ignored_keys ignored_key_handler
                 download_cache_dir].freeze

    # @return [String] The API key for your project, found on the project edit form.
    attr_reader :api_key

    # @return [String] The host to connect to (defaults to +copy-tuner.com+).
    attr_accessor :host

    # @return [Fixnum] The port on which your CopyTuner server runs (defaults to +443+ for secure connections, +80+ for insecure connections).
    attr_accessor :port

    # @return [Boolean] +true+ for https connections, +false+ for http connections.
    attr_accessor :secure

    # @return [Fixnum] The HTTP open timeout in seconds (defaults to +2+).
    attr_accessor :http_open_timeout

    # @return [Fixnum] The HTTP read timeout in seconds (defaults to +5+).
    attr_accessor :http_read_timeout

    # @return [String, NilClass] The hostname of your proxy server (if using a proxy)
    attr_accessor :proxy_host

    # @return [String, Fixnum] The port of your proxy server (if using a proxy)
    attr_accessor :proxy_port

    # @return [String, NilClass] The username to use when logging into your proxy server (if using a proxy)
    attr_accessor :proxy_user

    # @return [String, NilClass] The password to use when logging into your proxy server (if using a proxy)
    attr_accessor :proxy_pass

    # @return [Array<String>] A list of environments in which content should be editable
    attr_accessor :development_environments

    # @return [Array<String>] A list of environments in which the server should not be contacted
    attr_accessor :test_environments

    # @return [Array<String>] A list of environments in which the server should not be upload
    attr_accessor :upload_disabled_environments

    # @return [String] The name of the environment the application is running in
    attr_accessor :environment_name

    # @return [String] The name of the client library being used to send notifications (defaults to +CopyTuner Client+)
    attr_accessor :client_name

    # @return [String, NilClass] The framework notifications are being sent from, if any (such as +Rails 2.3.9+)
    attr_accessor :framework

    # @return [String] The version of the client library being used to send notifications (such as +1.0.2+)
    attr_accessor :client_version

    # @return [String] The url of the client library being used
    attr_accessor :client_url

    # @return [Integer] The time, in seconds, in between each sync to the server. Defaults to +300+.
    attr_accessor :polling_delay

    # @return [Integer] The time, in seconds, in between each sync to the server in development. Defaults to +60+.
    attr_accessor :sync_interval

    # @return [Integer] The time, in seconds, in between each sync to the server in development. Defaults to +60+.
    attr_accessor :sync_interval_staging

    # @return [Regex] Format ignore hook middleware sync
    attr_accessor :sync_ignore_path_regex

    # @return [Logger] Where to log messages. Must respond to same interface as Logger.
    attr_reader :logger

    # @return the middleware stack, if any, which should respond to +use+
    attr_accessor :middleware

    # @return [Boolean] disable middleware setting
    attr_accessor :disable_middleware

    # {before: OtherMiddleware} or {after: OtherMiddleware}
    attr_accessor :middleware_position

    # @return [Boolean] disable download translation for test enviroment
    attr_accessor :disable_test_translation

    # @return [String] the path to a root certificate file used to verify ssl sessions. Default's to the root certificate file for copy-tuner.com.
    attr_accessor :ca_file

    # @return [Cache] instance used internally to synchronize changes.
    attr_accessor :cache

    # @return [Client] instance used to communicate with a CopyTuner Server.
    attr_accessor :client

    attr_accessor :poller

    # @return [Regexp] Regular expression to exclude keys.
    attr_accessor :exclude_key_regexp

    # @return [String] The S3 host to connect to (defaults to +copy-tuner-us.s3.amazonaws.com+).
    attr_accessor :s3_host

    # @return [Boolean] To disable Copyray comment injection, set true
    attr_accessor :disable_copyray_comment_injection

    # @return [Array<Symbol>] Restrict blurb locales to upload
    attr_accessor :locales

    # @return [Boolean] Html escape
    attr_accessor :html_escape

    # @return [Array<String>] A list of ignored keys
    attr_accessor :ignored_keys

    # @return [Proc]
    attr_accessor :ignored_key_handler

    # @return [Integer] The project id
    attr_accessor :project_id

    # @return [Pathname] The directory to cache downloaded files
    attr_accessor :download_cache_dir

    alias secure? secure

    # Instantiated from {CopyTunerClient.configure}. Sets defaults.
    def initialize
      self.client_name = 'CopyTuner Client'
      self.client_url = 'https://rubygems.org/gems/copy_tuner_client'
      self.client_version = VERSION
      self.development_environments = %w[development staging]
      self.host = 'copy-tuner.com'
      self.http_open_timeout = 5
      self.http_read_timeout = 5
      self.logger = Logger.new($stdout)
      self.polling_delay = 300
      self.sync_interval = 60
      self.sync_interval_staging = 0
      self.secure = true
      self.test_environments = %w[test cucumber]
      self.upload_disabled_environments = %w[production staging]
      self.s3_host = 'copy-tuner.sg-apps.com' # NOTE: cloudfront host
      self.disable_copyray_comment_injection = false
      self.html_escape = true
      self.ignored_keys = []
      self.ignored_key_handler = ->(e) { raise e }
      self.project_id = nil
      self.download_cache_dir = Pathname.new(Dir.pwd).join('tmp', 'cache', 'copy_tuner_client')

      @applied = false
    end

    # Allows config options to be read like a hash
    #
    # @param [Symbol] option Key for a given attribute
    # @return [Object] the given attribute
    def [](option)
      send(option)
    end

    # Returns a hash of all configurable options
    # @return [Hash] configuration attributes
    def to_hash
      base_options = { public: public?, upload_disabled: upload_disabled? }

      OPTIONS.inject(base_options) do |hash, option|
        hash.merge option.to_sym => send(option)
      end
    end

    # Returns a hash of all configurable options merged with +hash+
    #
    # @param [Hash] hash A set of configuration options that will take precedence over the defaults
    # @return [Hash] the merged configuration hash
    def merge(hash)
      to_hash.merge hash
    end

    # Determines if the published or draft content will be used
    # @return [Boolean] Returns +false+ if in a development or test
    # environment, +true+ otherwise.
    def public?
      !(development_environments + test_environments).include?(environment_name)
    end

    # Determines if the content will be editable
    # @return [Boolean] Returns +true+ if in a development environment, +false+ otherwise.
    def development?
      development_environments.include? environment_name
    end

    def enable_middleware?
      middleware && development? && !disable_middleware
    end

    # Determines if the content will fetched from the server
    # @return [Boolean] Returns +true+ if in a test environment, +false+ otherwise.
    def test?
      test_environments.include?(environment_name)
    end

    def upload_disabled?
      upload_disabled_environments.include?(environment_name)
    end

    # Determines if the configuration has been applied (internal)
    # @return [Boolean] Returns +true+ if applied, +false+ otherwise.
    def applied?
      @applied
    end

    # Applies the configuration (internal).
    #
    # Called automatically when {CopyTunerClient.configure} is called in the application.
    #
    # This creates the {I18nBackend} and puts them together.
    #
    # When {#test?} returns +false+, the poller will be started.
    def apply
      self.locales ||= self.locales = if defined?(::Rails)
                                        ::Rails.application.config.i18n.available_locales.presence || Array(::Rails.application.config.i18n.default_locale)
                                      else
                                        [:en]
                                      end

      self.client ||= Client.new(to_hash)
      self.cache ||= Cache.new(client, to_hash)
      @poller = Poller.new(cache, to_hash)
      process_guard = ProcessGuard.new(cache, @poller, to_hash)
      I18n.backend = I18nBackend.new(cache)

      if enable_middleware?
        logger.info 'Using copytuner sync middleware'
        request_sync_options = { poller: @poller, cache:, interval: sync_interval, ignore_regex: sync_ignore_path_regex }
        if middleware_position.is_a?(Hash) && middleware_position[:before]
          middleware.insert_before middleware_position[:before], RequestSync, request_sync_options
          middleware.insert_before middleware_position[:before], CopyTunerClient::CopyrayMiddleware
        elsif middleware_position.is_a?(Hash) && middleware_position[:after]
          middleware.insert_after middleware_position[:after], RequestSync, request_sync_options
          middleware.insert_after middleware_position[:after], CopyTunerClient::CopyrayMiddleware
        else
          middleware.use RequestSync, request_sync_options
          middleware.use CopyTunerClient::CopyrayMiddleware
        end
      else
        logger.info '[[[Warn]]] Not using copytuner sync middleware' unless middleware
      end

      @applied = true
      logger.info "Client #{VERSION} ready (s3_download)"
      logger.info "Environment Info: #{environment_info}"
      logger.info "Available locales: #{self.locales.join(' ')}"

      unless test?
        process_guard.start
      end

      unless test? && disable_test_translation
        logger.info 'Download translation now'
        cache.download
      end
    end

    def port
      @port || default_port
    end

    # The protocol that should be used when generating URLs to CopyTuner.
    # @return [String] +https+ if {#secure?} returns +true+, +http+ otherwise.
    def protocol
      if secure?
        'https'
      else
        'http'
      end
    end

    # For logging/debugging (internal).
    # @return [String] a description of the environment in which this configuration was built.
    def environment_info
      parts = ["Ruby: #{RUBY_VERSION}", framework, "Env: #{environment_name}"]
      parts.compact.map { |part| "[#{part}]" }.join(' ')
    end

    # Wraps the given logger in a PrefixedLogger. This way, CopyTunerClient
    # log messages are recognizable.
    # @param original_logger [Logger] the upstream logger to use, which must respond to the standard +Logger+ severity methods.
    def logger=(original_logger)
      @logger = PrefixedLogger.new('** [CopyTuner]', original_logger)
    end

    def api_key=(api_key)
      raise ArgumentError, 'api_key is required' if api_key.nil? || api_key.empty?

      @api_key = api_key
    end

    # Sync interval for Rack Middleware
    def sync_interval
      if environment_name == 'staging'
        @sync_interval_staging
      else
        @sync_interval
      end
    end

    # @return [String] current project url by api_key
    def project_url
      path =
        if project_id
          "/projects/#{project_id}"
        else
          ActiveSupport::Deprecation.new.warn('Please set project_id.')
          "/projects/#{api_key}"
        end

      URI::Generic.build(scheme: self.protocol, host: self.host, port: self.port.to_i, path:).to_s
    end

    private

    def default_port
      if secure?
        443
      else
        80
      end
    end
  end
end

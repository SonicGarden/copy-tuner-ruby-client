require 'copy_tuner_client/client'
require 'copy_tuner_client/dotted_hash'

module CopyTunerClient
  # Manages synchronization of copy between {I18nBackend} and {Client}. Acts
  # like a Hash. Applications using the client will not need to interact with
  # this class directly.
  #
  # Responsible for locking down access to data used by both threads.
  class Cache
    STATUS_NOT_READY = :not_ready
    STATUS_PENDING = :pending
    STATUS_READY = :ready

    # Usually instantiated when {Configuration#apply} is invoked.
    # @param client [Client] the client used to fetch and upload data
    # @param options [Hash]
    # @option options [Logger] :logger where errors should be logged
    def initialize(client, options)
      @client = client
      @logger = options[:logger]
      @mutex = Mutex.new
      @exclude_key_regexp = options[:exclude_key_regexp]
      @upload_disabled = options[:upload_disabled]
      @ignored_keys = options.fetch(:ignored_keys, [])
      @ignored_key_handler = options.fetch(:ignored_key_handler, -> (e) { raise e })
      @locales = Array(options[:locales]).map(&:to_s)
      # mutable states
      @blurbs = {}
      @blank_keys = Set.new
      @queued = {}
      @status = STATUS_NOT_READY
    end

    # Returns content for the given blurb.
    # @param key [String] the key of the desired blurb
    # @return [String] the contents of the blurb
    def [](key)
      lock { @blurbs[key] }
    end

    # Sets content for the given blurb. The content will be pushed to the
    # server on the next flush.
    # @param key [String] the key of the blurb to update
    # @param value [String] the new contents of the blurb
    def []=(key, value)
      return if @exclude_key_regexp && key.match?(@exclude_key_regexp)
      return unless key.include?('.')
      return if @locales.present? && !@locales.member?(key.split('.').first)
      return if @upload_disabled

      # NOTE: config/locales以下のファイルに除外キーが残っていた場合の対応
      key_without_locale = key.split('.')[1..].join('.')
      if @ignored_keys.include?(key_without_locale)
        @ignored_key_handler.call(IgnoredKey.new("Ignored key: #{key_without_locale}"))
      end

      lock do
        return if @blank_keys.member?(key) || @blurbs.key?(key)

        @queued[key] = value
      end
    end

    # Keys for all blurbs stored on the server.
    # @return [Array<String>] keys
    def keys
      lock { @blurbs.keys }
    end

    # Yaml representation of all blurbs
    # @return [String] yaml
    def export
      tree_hash = to_tree_hash
      tree_hash.present? ? tree_hash.to_yaml : nil
    end

    # ツリー構造のハッシュを返す（I18nBackend用）
    # @return [Hash] ツリー構造に変換されたblurbs
    def to_tree_hash
      lock { @blurbs.present? ? DottedHash.to_h(@blurbs) : {} }
    end

    # キャッシュの更新バージョンを返す（ツリーキャッシュの無効化判定用）
    # ETags を使用してサーバーサイドの更新を検知
    # @return [String, nil] 現在のETag値
    def version
      client.etag
    end

    # Waits until the first download has finished.
    def wait_for_download
      return unless pending?

      logger.info 'Waiting for first download'

      if logger.respond_to? :flush
        logger.flush
      end

      sleep 0.1 while pending?
    end

    def flush
      res = with_queued_changes do |queued|
        client.upload queued
      end

      @last_uploaded_at = Time.now.utc

      res
    rescue ConnectionError => e
      logger.error e.message
    end

    def download
      @status = STATUS_PENDING unless ready?

      res = client.download(cache_fallback: pending?) do |downloaded_blurbs|
        blank_blurbs, blurbs = downloaded_blurbs.partition { |_key, value| value == '' }
        lock do
          @blank_keys = Set.new(blank_blurbs.map(&:first))
          @blurbs = blurbs.to_h
        end
      end

      @last_downloaded_at = Time.now.utc
      @status = STATUS_READY unless ready?

      res
    rescue ConnectionError => e
      logger.error e.message
      raise e unless ready?
    end

    # Downloads and then flushes
    def sync
      download
      flush
    end

    attr_reader :last_downloaded_at, :last_uploaded_at, :queued, :blurbs

    def inspect
      "#<CopyTunerClient::Cache:#{object_id}>"
    end

    def pending?
      @status == STATUS_PENDING
    end

    def ready?
      @status == STATUS_READY
    end

    private

    attr_reader :client, :logger

    def with_queued_changes
      changes_to_push = nil

      lock do
        unless @queued.empty?
          changes_to_push = @queued
          @queued = {}
        end
      end

      if changes_to_push
        yield nil_value_to_empty(changes_to_push)
      end
    end

    def nil_value_to_empty(hash)
      hash.each do |k, v|
        if v.nil?
          hash[k] = ''.freeze
        elsif v.is_a?(Hash)
          nil_value_to_empty(v)
        end
      end
      hash
    end

    def lock(&block)
      @mutex.synchronize &block
    end
  end
end

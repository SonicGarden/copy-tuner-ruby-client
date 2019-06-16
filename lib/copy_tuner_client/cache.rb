require 'thread'
require 'copy_tuner_client/client'

module CopyTunerClient
  # Manages synchronization of copy between {I18nBackend} and {Client}. Acts
  # like a Hash. Applications using the client will not need to interact with
  # this class directly.
  #
  # Responsible for locking down access to data used by both threads.
  class Cache
    # Usually instantiated when {Configuration#apply} is invoked.
    # @param client [Client] the client used to fetch and upload data
    # @param options [Hash]
    # @option options [Logger] :logger where errors should be logged
    def initialize(client, options)
      @client = client
      @logger = options[:logger]
      @mutex = Mutex.new
      @exclude_key_regexp = options[:exclude_key_regexp]
      @locales = Array(options[:locales]).map(&:to_s)
      @raise_when_invalid_key = options[:raise_when_invalid_key]
      # mutable states
      @blurbs = {}
      @blank_keys = Set.new
      @queued = {}
      @started = false
      @downloaded = false
      @scopes = Set.new
      @queued_scopes = Set.new
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
      return if @locales.present? && !@locales.member?(key.split('.').first)
      lock do
        return if @blank_keys.member?(key)
        check_already_scope!(key)
        @queued[key] = value
        @queued_scopes = @queued_scopes + key_to_scopes(key)
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
      keys = {}
      lock do
        @blurbs.sort.each do |(blurb_key, value)|
          current = keys
          yaml_keys = blurb_key.split('.')

          0.upto(yaml_keys.size - 2) do |i|
            key = yaml_keys[i]

            # Overwrite en.key with en.sub.key
            unless current[key].class == Hash
              current[key] = {}
            end

            current = current[key]
          end

          current[yaml_keys.last] = value
        end
      end

      unless keys.size < 1
        keys.to_yaml
      end
    end

    # Waits until the first download has finished.
    def wait_for_download
      if pending?
        logger.info 'Waiting for first download'

        if logger.respond_to? :flush
          logger.flush
        end

        while pending?
          sleep 0.1
        end
      end
    end

    def flush
      res = with_queued_changes do |queued|
        client.upload queued
      end

      @last_uploaded_at = Time.now.utc

      res
    rescue ConnectionError => error
      logger.error error.message
    end

    def download
      @started = true

      res = client.download do |downloaded_blurbs|
        blank_blurbs, blurbs = downloaded_blurbs.partition { |_key, value| value == '' }
        lock do
          @blank_keys = Set.new(blank_blurbs.to_h.keys)
          @blurbs = blurbs.to_h
          @scopes = key_to_scopes(@blurbs.keys)
        end
      end

      @last_downloaded_at = Time.now.utc

      res
    rescue ConnectionError => error
      logger.error error.message
    ensure
      @downloaded = true
    end

    # Downloads and then flushes
    def sync
      download
      flush
    end

    attr_reader :last_downloaded_at, :last_uploaded_at, :queued

    def inspect
      "#<CopyTunerClient::Cache:#{object_id}>"
    end

    def pending?
      @started && !@downloaded
    end

    private

    attr_reader :client, :logger

    def with_queued_changes
      changes_to_push = nil

      lock do
        unless @queued.empty?
          changes_to_push = @queued
          @queued = {}
          @queued_scopes.clear
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

    def check_already_scope!(key)
      already_scope =
        if (@scopes + @queued_scopes).member?(key)
          key
        else
          already_keys = Set.new(@blurbs.keys + @queued.keys) & key_to_scopes(key)
          already_keys.empty? ? nil : already_keys.to_a.last
        end
      return if already_scope.nil?

      message = "Scope already exists: #{already_scope}"
      raise ArgumentError, message if @raise_when_invalid_key
      logger.error message
    end

    def key_to_scopes(keys)
      scopes =
        Array(keys).flat_map do |key|
          key.split('.').inject([]) do |memo, k|
            memo << (memo.present? ? [memo.last, k].join('.') : k)
          end
        end
      Set.new(scopes)
    end

    def lock(&block)
      @mutex.synchronize &block
    end
  end
end

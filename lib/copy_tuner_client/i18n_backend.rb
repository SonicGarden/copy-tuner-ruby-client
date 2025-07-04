require 'i18n'
require 'copy_tuner_client/configuration'
require 'active_support/core_ext/hash/keys'

module CopyTunerClient
  # I18n implementation designed to synchronize with CopyTuner.
  #
  # Expects an object that acts like a Hash, responding to +[]+, +[]=+, and +keys+.
  #
  # This backend will be used as the default I18n backend when the client is
  # configured, so you will not need to instantiate this class from the
  # application. Instead, just use methods on the I18n class.
  #
  # This implementation will also load translations from locale files.
  class I18nBackend
    include I18n::Backend::Simple::Implementation

    # Usually instantiated when {Configuration#apply} is invoked.
    # @param cache [Cache] must act like a hash, returning and accept blurbs by key.
    def initialize(cache)
      @cache = cache
      @tree_cache = nil
      @cache_version = nil
    end    # Translates the given local and key. See the I18n API documentation for details.
    #
    # @return [Object] the translated key (usually a String)
    def translate(locale, key, options = {})
      # I18nの標準処理に任せる（内部でlookupが呼ばれる）
      content = super(locale, key, options)

      return content if content.nil? || content.is_a?(Hash)

      # HTML escapeの処理（ツリー構造のHashは除く）
      if CopyTunerClient.configuration.html_escape
        content
      else
        # Backward compatible
        content.respond_to?(:html_safe) ? content.html_safe : content
      end
    end

    # Returns locales available for this CopyTuner project.
    # @return [Array<String>] available locales
    def available_locales
      return @available_locales if defined?(@available_locales)
      cached_locales = cache.keys.map { |key| key.split('.').first }
      @available_locales = (cached_locales + super).uniq.map { |locale| locale.to_sym }
    end

    # Stores the given translations.
    #
    # Updates will be visible in the current process immediately, and will
    # propagate to CopyTuner during the next flush.
    #
    # @param [String] locale the locale (ie "en") to store translations for
    # @param [Hash] data nested key-value pairs to be added as blurbs
    # @param [Hash] options unused part of the I18n API
    def store_translations(locale, data, options = {})
      super
      store_item(locale, data)
    end

    private

    def lookup(locale, key, scope = [], options = {})
      return nil if !key.is_a?(String) && !key.is_a?(Symbol)

      parts = I18n.normalize_keys(locale, key, scope, options[:separator])
      key_with_locale = parts.join('.')
      key_without_locale = parts[1..].join('.')

      if CopyTunerClient::configuration.ignored_keys.include?(key_without_locale)
        CopyTunerClient::configuration.ignored_key_handler.call(IgnoredKey.new("Ignored key: #{key_without_locale}"))
      end

      # NOTE: ハッシュ化した場合に削除されるキーに対応するため、最初に完全一致をチェック（旧クライアントの動作を維持）
      # 例: `en.test.key` が `en.test.key.conflict` のように別のキーで上書きされている場合の対応
      exact_match = cache[key_with_locale]
      if exact_match
        return exact_match
      end

      # NOTE: 色々考慮する必要があることが分かったため暫定対応として、ツリーキャッシュを使用しないようにしている
      # ensure_tree_cache_current
      # tree_result = lookup_in_tree_cache(parts)
      # return tree_result if tree_result

      content = super

      if content.nil?
        cache[key_with_locale] = nil
      end

      content
    end

    def ensure_tree_cache_current
      current_version = cache.version
      # ETag が nil の場合（初回ダウンロード前）や変更があった場合のみ更新
      # 初回は @cache_version が nil なので、必ず更新される
      if @cache_version != current_version || @tree_cache.nil?
        @tree_cache = cache.to_tree_hash.deep_symbolize_keys
        @cache_version = current_version
      end
    end

    def lookup_in_tree_cache(keys)
      return nil if @tree_cache.nil?

      symbol_keys = keys.map(&:to_sym)
      begin
        result = @tree_cache.dig(*symbol_keys)
        result.is_a?(Hash) ? result : nil
      rescue TypeError
        # Handle the case where dig encounters a non-Hash value
        # (e.g., when ja.hoge exists as a string and ja.hoge.hello is searched)
        nil
      end
    end

    def store_item(locale, data, scope = [])
      if data.respond_to?(:to_hash)
        data.to_hash.each do |key, value|
          store_item(locale, value, scope + [key])
        end
      elsif data.respond_to?(:to_str)
        key = ([locale] + scope).join('.')
        cache[key] = data.to_str
      end
    end

    def load_translations(*filenames)
      super
      cache.wait_for_download
    end

    def default(locale, object, subject, options = {})
      content = super(locale, object, subject, options)
      return content if !object.is_a?(String) && !object.is_a?(Symbol)

      if content.respond_to?(:to_str)
        parts = I18n.normalize_keys(locale, object, options[:scope], options[:separator])
        # NOTE: ActionView::Helpers::TranslationHelper#translate wraps default String in an Array
        if subject.is_a?(String) || (subject.is_a?(Array) && subject.size == 1 && subject.first.is_a?(String))
          key = parts.join('.')
          cache[key] = content.to_str
        end
      end
      content
    end

    attr_reader :cache
  end
end

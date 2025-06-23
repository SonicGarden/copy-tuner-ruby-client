require 'i18n'
require 'copy_tuner_client/configuration'

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

      # HTML escapeの処理（ツリー構造のHashは除く）
      if content && !content.is_a?(Hash)
        content = unless CopyTunerClient.configuration.html_escape
          # Backward compatible
          content.respond_to?(:html_safe) ? content.html_safe : content
        else
          content
        end
      end

      content
    end

    # Returns locales availabile for this CopyTuner project.
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

      # 1. 最初に完全一致をチェック（現在の動作を維持）
      exact_match = cache[key_with_locale]
      if exact_match
        return exact_match
      end

      # 2. 完全一致がない場合のみツリー構造をチェック
      ensure_tree_cache_current
      tree_result = lookup_in_tree_cache(parts)
      return tree_result if tree_result      # 3. ツリー構造にもない場合は親クラスのlookupを呼び出し
      content = super

      # 4. 既存のnil値処理 - contentがnilの場合のみ設定
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
        tree_hash = cache.to_tree_hash
        # DottedHash.to_hは文字列キーを返すので、シンボルキーに変換
        @tree_cache = deep_symbolize_keys(tree_hash)
        @cache_version = current_version
      end
    end

    def deep_symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        new_key = key.to_sym
        new_value = value.is_a?(Hash) ? deep_symbolize_keys(value) : value
        result[new_key] = new_value
      end
    end

    def lookup_in_tree_cache(keys)
      # ツリーキャッシュが未初期化の場合は nil を返す
      return nil if @tree_cache.nil?

      current_level = @tree_cache
      keys.each do |key|
        return nil unless current_level.is_a?(Hash)

        # シンボルキーを優先して検索
        if current_level.has_key?(key.to_sym)
          current_level = current_level[key.to_sym]
        elsif current_level.has_key?(key)
          current_level = current_level[key]
        elsif current_level.has_key?(key.to_s)
          current_level = current_level[key.to_s]
        else
          return nil
        end
      end

      # 最終結果がHashの場合は返す（部分ツリー）、そうでなければnil
      current_level.is_a?(Hash) ? current_level : nil
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

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
    end

    #
    # @return [Object] the translated key (usually a String)
    def translate(locale, key, options = {})
      # I18nの標準処理に任せる（内部でlookupが呼ばれる）。
      # NOTE: html_safe 化は backend では行わない。.html/_html キーの html_safe 化は
      # ActionView の TranslationHelper（ActiveSupport::HtmlSafeTranslation）が担うため、
      # backend は I18n 標準どおり素の content を返すだけにする（旧 html_escape 分岐は廃止）。
      super
    end

    # Returns locales available for this CopyTuner project.
    # @return [Array<String>] available locales
    def available_locales
      return @available_locales if defined?(@available_locales)

      cached_locales = cache.keys.map { |key| key.split('.').first }
      @available_locales = (cached_locales + super).uniq.map(&:to_sym)
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

    def lookup(locale, key, scope = [], options = {}) # rubocop:disable Metrics/MethodLength
      return nil if !key.is_a?(String) && !key.is_a?(Symbol)

      parts = I18n.normalize_keys(locale, key, scope, options[:separator])
      key_with_locale = parts.join('.')
      key_without_locale = parts[1..].join('.')

      # NOTE: local_first_key_regexp にマッチするキーは copy_tuner キャッシュをスキップし、
      # ローカル config/locales（I18n::Backend::Simple）を優先する。段階的にローカルへ移行するための仕組み。
      # ローカルに無い場合は nil（未訳）のまま返し、copy_tuner へのフォールバックも空キー登録も行わない（完全分離）。
      # ignored_keys より先に評価することで、両方にマッチするキーでも確実にローカルへ委譲する。
      if local_first_key?(key_without_locale)
        return super
      end

      config = CopyTunerClient.configuration
      if config.ignored_keys.include?(key_without_locale)
        config.ignored_key_handler.call(IgnoredKey.new("Ignored key: #{key_without_locale}"))
      end

      # NOTE: ハッシュ化した場合に削除されるキーに対応するため、最初に完全一致をチェック（旧クライアントの動作を維持）
      # 例: `en.test.key` が `en.test.key.conflict` のように別のキーで上書きされている場合の対応
      exact_match = cache[key_with_locale]
      if exact_match
        return exact_match
      end

      ensure_tree_cache_current
      tree_result = lookup_in_tree_cache(parts)
      return tree_result if tree_result

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

      # NOTE: keys は I18n.normalize_keys 済みの配列で、数字だけのセグメントは Integer になっている
      # （例: "...body_temperature.36.5" は [..., 36, 5] に分割される）。Integer#to_sym は無いため to_s を経由する。
      symbol_keys = keys.map { |k| k.to_s.to_sym }
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

    def local_first_key?(key_without_locale)
      CopyTunerClient.configuration.local_first_key?(key_without_locale)
    end

    def default(locale, object, subject, options = {})
      content = super
      return content if !object.is_a?(String) && !object.is_a?(Symbol)

      if content.respond_to?(:to_str)
        parts = I18n.normalize_keys(locale, object, options[:scope], options[:separator])
        # NOTE: ActionView::Helpers::TranslationHelper#translate wraps default String in an Array
        # NOTE: local_first キーのアップロード抑止は Cache#[]= 側に集約している
        cache[parts.join('.')] = content.to_str if default_string_subject?(subject)
      end
      content
    end

    def default_string_subject?(subject)
      subject.is_a?(String) || (subject.is_a?(Array) && subject.size == 1 && subject.first.is_a?(String))
    end

    attr_reader :cache
  end
end

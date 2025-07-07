module CopyTunerClient
  module DottedHash
    def to_h(dotted_hash)
      hash = {}
      dotted_hash.to_h.transform_keys(&:to_s).sort.each do |key, value|
        # Rails i18n標準との互換性のため、特定のキーを適切な型に変換
        converted_value = convert_value_type(key, value)
        _hash = key.split('.').reverse.inject(converted_value) { |memo, key| { key => memo } }
        hash.deep_merge!(_hash)
      end
      hash
    end

    def conflict_keys(dotted_hash)
      all_keys = dotted_hash.keys.sort
      results = {}

      all_keys.each_with_index do |key, index|
        prefix = "#{key}."
        conflict_keys = ((index + 1)..Float::INFINITY)
          .take_while { |i| all_keys[i]&.start_with?(prefix) }
          .map { |i| all_keys[i] }

        if conflict_keys.present?
          results[key] = conflict_keys
        end
      end

      results
    end

    private

    def convert_value_type(key, value)
      return value unless value.is_a?(String)

      # Rails i18n標準で数値型として扱われるキー
      if key.end_with?('.precision')
        value.to_i
      # Rails i18n標準で真偽値として扱われるキー
      elsif key.end_with?('.significant', '.strip_insignificant_zeros')
        value == 'true'
      else
        value
      end
    end

    module_function :to_h, :conflict_keys, :convert_value_type
  end
end

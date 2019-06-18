module CopyTunerClient
  module DottedHash
    def to_h(dotted_hash)
      hash = {}
      dotted_hash.to_h.transform_keys(&:to_s).sort.each do |key, value|
        _hash = key.split('.').reverse.inject(value) { |memo, key| { key => memo } }
        hash.deep_merge!(_hash)
      end
      hash
    end

    def invalid_keys(dotted_hash)
      all_keys = dotted_hash.keys
      results = {}

      all_keys.sort.each do |key|
        invalid_keys = all_keys.find_all { |k| k.start_with?("#{key}.") }
        if invalid_keys.present?
          results[key] = invalid_keys
        end
      end

      results
    end

    module_function :to_h, :invalid_keys
  end
end

module CopyTunerClient
  # Encodes/decodes text into invisible Unicode characters (zero-width).
  # Used by the :subliminal copyray marker type to embed the translation key
  # into the rendered text without injecting any HTML.
  #
  # Bit format matches i18next-subliminal: 9 invisible characters per UTF-8
  # byte (8 data bits, MSB first, plus a trailing separator 0). Character set
  # is fixed to the browser-compatible pair so the frontend decoder matches:
  #   ZWNJ (U+200C) = bit 0, ZWJ (U+200D) = bit 1.
  module Subliminal
    module_function

    ZWNJ = '‌'.freeze # bit 0
    ZWJ = '‍'.freeze # bit 1
    INVISIBLE = [ZWNJ, ZWJ].freeze
    INVISIBLE_REGEX = /[#{ZWNJ}#{ZWJ}]+/

    # @param text [String]
    # @return [String] invisible representation (9 chars per UTF-8 byte)
    def encode(text)
      binary = text.b.bytes.map { |byte| "#{byte.to_s(2).rjust(8, '0')}0" }.join
      binary.each_char.map { |bit| INVISIBLE[bit.to_i] }.join
    end

    # @param message [String] invisible representation produced by {.encode}
    # @return [String] the decoded text
    def decode(message)
      binary = message.each_char.map { |char| INVISIBLE.index(char).to_s }.join
      bytes = binary.scan(/.{9}/).map { |chunk| chunk[0, 8].to_i(2) }
      bytes.pack('C*').force_encoding('UTF-8')
    end

    # Strips any invisible marker characters, leaving the visible text.
    # Non-string values are returned unchanged.
    def remove(text)
      text.is_a?(String) ? text.gsub(INVISIBLE_REGEX, '') : text
    end
  end
end

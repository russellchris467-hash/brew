# typed: strict
# frozen_string_literal: true

module Utils
  # Encode and decode hidden messages within emoji strings using Unicode
  # variation selectors as a steganographic channel.
  #
  # Each byte of the secret message is split into two 4-bit nibbles.
  # Each nibble (0-15) is mapped to a Unicode variation selector
  # (U+FE00 through U+FE0F). These selectors are invisible in most
  # renderers, so the carrier emoji string appears unchanged.
  module EmojiSteganography
    # Variation selectors VS1-VS16 (U+FE00 – U+FE0F)
    VS_BASE = T.let(0xFE00, Integer)

    # Default carrier emojis used when the caller does not supply a cover string.
    DEFAULT_CARRIER = T.let(
      "\u{1F37A}\u{1F3E0}\u{2615}\u{1F4E6}\u{1F680}",
      String,
    )

    class << self
      # Encode a secret message into a carrier emoji string.
      #
      # Each byte of +secret+ is represented as two consecutive variation
      # selectors appended after the first emoji in +carrier+.
      #
      # @param secret  [String] the plaintext message to hide
      # @param carrier [String] visible emoji string (default: beer + house + coffee + package + rocket)
      # @return [String] the carrier with embedded variation selectors
      sig { params(secret: String, carrier: String).returns(String) }
      def encode(secret, carrier: DEFAULT_CARRIER)
        raise ArgumentError, "Secret message must not be empty" if secret.empty?

        graphemes = carrier.grapheme_clusters
        raise ArgumentError, "Carrier must contain at least one grapheme" if graphemes.empty?

        payload = secret.bytes.flat_map { |byte| [byte >> 4, byte & 0x0F] }
                       .map { |nibble| [nibble + VS_BASE].pack("U") }
                       .join

        # Insert the payload right after the first grapheme cluster.
        graphemes[0] + payload + graphemes[1..].join
      end

      # Decode a hidden message from an emoji string.
      #
      # Extracts all variation selectors (U+FE00–U+FE0F) from +text+,
      # pairs them into bytes, and returns the recovered plaintext.
      #
      # @param text [String] the steganographic emoji string
      # @return [String] the decoded secret message
      sig { params(text: String).returns(String) }
      def decode(text)
        nibbles = text.each_char
                     .select { |ch| ch.ord >= VS_BASE && ch.ord <= VS_BASE + 15 }
                     .map { |ch| ch.ord - VS_BASE }

        raise ArgumentError, "No hidden data found in input" if nibbles.empty?
        raise ArgumentError, "Corrupt data: odd number of nibbles (#{nibbles.length})" if nibbles.length.odd?

        nibbles.each_slice(2)
               .map { |high, low| (T.must(high) << 4) | T.must(low) }
               .pack("C*")
               .force_encoding("UTF-8")
      end
    end
  end
end

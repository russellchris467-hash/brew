# frozen_string_literal: true

require "utils/emoji_steganography"

RSpec.describe Utils::EmojiSteganography do
  describe ".encode" do
    it "embeds a secret message into the default carrier" do
      result = described_class.encode("hi")
      # The visible emojis should still be present
      expect(result).to include("\u{1F37A}")
      # The result should be longer than the carrier due to hidden selectors
      expect(result.length).to be > described_class::DEFAULT_CARRIER.length
    end

    it "embeds a secret message into a custom carrier" do
      carrier = "\u{1F600}\u{1F601}"
      result = described_class.encode("A", carrier: carrier)
      expect(result).to include("\u{1F600}")
      expect(result).to include("\u{1F601}")
    end

    it "raises on empty secret" do
      expect { described_class.encode("") }.to raise_error(ArgumentError, /empty/)
    end

    it "raises on empty carrier" do
      expect { described_class.encode("x", carrier: "") }.to raise_error(ArgumentError, /grapheme/)
    end
  end

  describe ".decode" do
    it "recovers the original message from an encoded string" do
      secret = "Hello, brew!"
      encoded = described_class.encode(secret)
      expect(described_class.decode(encoded)).to eq(secret)
    end

    it "handles multibyte UTF-8 secrets" do
      secret = "\u{00E9}\u{00F1}" # é ñ
      encoded = described_class.encode(secret)
      decoded = described_class.decode(encoded)
      expect(decoded.bytes).to eq(secret.bytes)
    end

    it "roundtrips ASCII printable characters" do
      secret = (32..126).map(&:chr).join
      encoded = described_class.encode(secret)
      expect(described_class.decode(encoded)).to eq(secret)
    end

    it "raises when no hidden data is present" do
      expect { described_class.decode("just plain text") }.to raise_error(ArgumentError, /No hidden data/)
    end

    it "raises on corrupt (odd-nibble) data" do
      # Inject a single variation selector (one nibble)
      bad = "\u{1F600}\u{FE00}"
      expect { described_class.decode(bad) }.to raise_error(ArgumentError, /odd number/)
    end
  end

  describe "roundtrip" do
    it "encodes and decodes correctly with a single-emoji carrier" do
      carrier = "\u{2615}" # coffee
      secret = "steganography"
      expect(described_class.decode(described_class.encode(secret, carrier: carrier))).to eq(secret)
    end

    it "preserves binary-safe bytes" do
      secret = (0..255).map(&:chr).join.b
      encoded = described_class.encode(secret)
      decoded = described_class.decode(encoded)
      expect(decoded.bytes).to eq(secret.bytes)
    end
  end
end

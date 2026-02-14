# typed: strict
# frozen_string_literal: true

# A system for identifying cryptographic and non-cryptographic hash algorithms
# from their output strings. Useful for research, forensics, and security analysis.
module HashDetector
  # Represents a single identified hash algorithm match.
  class Match
    attr_reader :algorithm, :hash_length, :confidence, :category, :description

    def initialize(algorithm:, hash_length:, confidence:, category:, description:)
      @algorithm   = algorithm
      @hash_length = hash_length
      @confidence  = confidence
      @category    = category
      @description = description
    end

    def to_h
      {
        algorithm:   @algorithm,
        hash_length: @hash_length,
        confidence:  @confidence,
        category:    @category,
        description: @description,
      }
    end

    def to_s
      "#{@algorithm} (#{@category}) [confidence: #{@confidence}] - #{@description}"
    end
  end

  # Defines the pattern, metadata, and matching logic for a hash algorithm.
  class Pattern
    attr_reader :name, :regex, :length, :category, :description, :confidence_base

    def initialize(name:, regex:, length:, category:, description:, confidence_base: :medium)
      @name            = name
      @regex           = regex
      @length          = length
      @category        = category
      @description     = description
      @confidence_base = confidence_base
    end

    def match?(input)
      clean = input.strip
      return false unless @regex.match?(clean)
      return false if @length && clean.length != @length

      true
    end

    def build_match
      Match.new(
        algorithm:   @name,
        hash_length: @length,
        confidence:  @confidence_base,
        category:    @category,
        description: @description,
      )
    end
  end

  # Registry of all known hash patterns.
  module Patterns
    DEFINITIONS = [
      # ── MD family ──────────────────────────────────────────────
      Pattern.new(
        name:        "MD4",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :message_digest,
        description: "MD4 - 128-bit message digest (RFC 1320), considered broken",
      ),
      Pattern.new(
        name:        "MD5",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :message_digest,
        description: "MD5 - 128-bit message digest (RFC 1321), widely used but cryptographically broken",
      ),

      # ── SHA-1 ──────────────────────────────────────────────────
      Pattern.new(
        name:        "SHA-1",
        regex:       /\A[a-fA-F0-9]{40}\z/,
        length:      40,
        category:    :sha,
        description: "SHA-1 - 160-bit digest (FIPS 180-4), deprecated for security use",
      ),
      Pattern.new(
        name:        "RIPEMD-160",
        regex:       /\A[a-fA-F0-9]{40}\z/,
        length:      40,
        category:    :ripemd,
        description: "RIPEMD-160 - 160-bit digest, used in Bitcoin address generation",
      ),

      # ── SHA-2 family ───────────────────────────────────────────
      Pattern.new(
        name:        "SHA-224",
        regex:       /\A[a-fA-F0-9]{56}\z/,
        length:      56,
        category:    :sha,
        description: "SHA-224 - 224-bit truncated variant of SHA-256 (FIPS 180-4)",
      ),
      Pattern.new(
        name:        "SHA-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :sha,
        description: "SHA-256 - 256-bit digest (FIPS 180-4), widely used in TLS, Bitcoin, etc.",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "SHA-384",
        regex:       /\A[a-fA-F0-9]{96}\z/,
        length:      96,
        category:    :sha,
        description: "SHA-384 - 384-bit truncated variant of SHA-512 (FIPS 180-4)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "SHA-512",
        regex:       /\A[a-fA-F0-9]{128}\z/,
        length:      128,
        category:    :sha,
        description: "SHA-512 - 512-bit digest (FIPS 180-4)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "SHA-512/224",
        regex:       /\A[a-fA-F0-9]{56}\z/,
        length:      56,
        category:    :sha,
        description: "SHA-512/224 - 224-bit truncated variant of SHA-512",
      ),
      Pattern.new(
        name:        "SHA-512/256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :sha,
        description: "SHA-512/256 - 256-bit truncated variant of SHA-512",
      ),

      # ── SHA-3 family ───────────────────────────────────────────
      Pattern.new(
        name:        "SHA3-224",
        regex:       /\A[a-fA-F0-9]{56}\z/,
        length:      56,
        category:    :sha3,
        description: "SHA3-224 - 224-bit Keccak-based digest (FIPS 202)",
      ),
      Pattern.new(
        name:        "SHA3-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :sha3,
        description: "SHA3-256 - 256-bit Keccak-based digest (FIPS 202)",
      ),
      Pattern.new(
        name:        "SHA3-384",
        regex:       /\A[a-fA-F0-9]{96}\z/,
        length:      96,
        category:    :sha3,
        description: "SHA3-384 - 384-bit Keccak-based digest (FIPS 202)",
      ),
      Pattern.new(
        name:        "SHA3-512",
        regex:       /\A[a-fA-F0-9]{128}\z/,
        length:      128,
        category:    :sha3,
        description: "SHA3-512 - 512-bit Keccak-based digest (FIPS 202)",
      ),

      # ── BLAKE family ───────────────────────────────────────────
      Pattern.new(
        name:        "BLAKE2s-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :blake,
        description: "BLAKE2s-256 - 256-bit digest optimized for 32-bit platforms (RFC 7693)",
      ),
      Pattern.new(
        name:        "BLAKE2b-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :blake,
        description: "BLAKE2b-256 - 256-bit digest optimized for 64-bit platforms (RFC 7693)",
      ),
      Pattern.new(
        name:        "BLAKE2b-384",
        regex:       /\A[a-fA-F0-9]{96}\z/,
        length:      96,
        category:    :blake,
        description: "BLAKE2b-384 - 384-bit BLAKE2b variant",
      ),
      Pattern.new(
        name:        "BLAKE2b-512",
        regex:       /\A[a-fA-F0-9]{128}\z/,
        length:      128,
        category:    :blake,
        description: "BLAKE2b-512 - 512-bit BLAKE2b variant (RFC 7693)",
      ),
      Pattern.new(
        name:        "BLAKE3",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :blake,
        description: "BLAKE3 - 256-bit default output, modern high-performance hash",
      ),

      # ── Non-cryptographic hashes ───────────────────────────────
      Pattern.new(
        name:        "CRC-16",
        regex:       /\A[a-fA-F0-9]{4}\z/,
        length:      4,
        category:    :checksum,
        description: "CRC-16 - 16-bit cyclic redundancy check",
        confidence_base: :low,
      ),
      Pattern.new(
        name:        "CRC-32",
        regex:       /\A[a-fA-F0-9]{8}\z/,
        length:      8,
        category:    :checksum,
        description: "CRC-32 - 32-bit cyclic redundancy check (ISO 3309)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "Adler-32",
        regex:       /\A[a-fA-F0-9]{8}\z/,
        length:      8,
        category:    :checksum,
        description: "Adler-32 - 32-bit checksum used in zlib (RFC 1950)",
      ),
      Pattern.new(
        name:        "xxHash32",
        regex:       /\A[a-fA-F0-9]{8}\z/,
        length:      8,
        category:    :non_cryptographic,
        description: "xxHash32 - 32-bit non-cryptographic hash, extremely fast",
      ),
      Pattern.new(
        name:        "xxHash64",
        regex:       /\A[a-fA-F0-9]{16}\z/,
        length:      16,
        category:    :non_cryptographic,
        description: "xxHash64 - 64-bit non-cryptographic hash, extremely fast",
      ),
      Pattern.new(
        name:        "xxHash128 / MurmurHash3-128",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :non_cryptographic,
        description: "xxHash128 or MurmurHash3-128 - 128-bit non-cryptographic hash",
      ),
      Pattern.new(
        name:        "FNV-1/FNV-1a (32-bit)",
        regex:       /\A[a-fA-F0-9]{8}\z/,
        length:      8,
        category:    :non_cryptographic,
        description: "FNV-1 or FNV-1a - 32-bit Fowler-Noll-Vo hash",
      ),
      Pattern.new(
        name:        "FNV-1/FNV-1a (64-bit)",
        regex:       /\A[a-fA-F0-9]{16}\z/,
        length:      16,
        category:    :non_cryptographic,
        description: "FNV-1 or FNV-1a - 64-bit Fowler-Noll-Vo hash",
      ),

      # ── Password hashes (structured formats) ──────────────────
      Pattern.new(
        name:        "bcrypt",
        regex:       /\A\$2[aby]?\$\d{2}\$[.\/A-Za-z0-9]{53}\z/,
        length:      60,
        category:    :password,
        description: "bcrypt - Blowfish-based adaptive password hash",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "scrypt",
        regex:       /\A\$scrypt\$/,
        length:      nil,
        category:    :password,
        description: "scrypt - Memory-hard password hash (RFC 7914)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "Argon2",
        regex:       /\A\$argon2(i|d|id)\$/,
        length:      nil,
        category:    :password,
        description: "Argon2 - Memory-hard password hash (PHC winner), variants: i, d, id",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "PBKDF2-SHA256",
        regex:       /\A\$pbkdf2-sha256\$/,
        length:      nil,
        category:    :password,
        description: "PBKDF2-SHA256 - Password-Based Key Derivation Function 2 (RFC 2898)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "PBKDF2-SHA512",
        regex:       /\A\$pbkdf2-sha512\$/,
        length:      nil,
        category:    :password,
        description: "PBKDF2-SHA512 - PBKDF2 with SHA-512",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "MD5-crypt",
        regex:       /\A\$1\$[.\/0-9A-Za-z]{1,8}\$[.\/0-9A-Za-z]{22}\z/,
        length:      nil,
        category:    :password,
        description: "MD5-crypt - Unix MD5-based password hash ($1$)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "SHA-256-crypt",
        regex:       /\A\$5\$(rounds=\d+\$)?[.\/0-9A-Za-z]{1,16}\$[.\/0-9A-Za-z]{43}\z/,
        length:      nil,
        category:    :password,
        description: "SHA-256-crypt - Unix SHA-256-based password hash ($5$)",
        confidence_base: :high,
      ),
      Pattern.new(
        name:        "SHA-512-crypt",
        regex:       /\A\$6\$(rounds=\d+\$)?[.\/0-9A-Za-z]{1,16}\$[.\/0-9A-Za-z]{86}\z/,
        length:      nil,
        category:    :password,
        description: "SHA-512-crypt - Unix SHA-512-based password hash ($6$)",
        confidence_base: :high,
      ),

      # ── NTLM / LM ─────────────────────────────────────────────
      Pattern.new(
        name:        "NTLM",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :windows,
        description: "NTLM - Windows NT LAN Manager hash (MD4-based)",
      ),
      Pattern.new(
        name:        "LM",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :windows,
        description: "LM - LAN Manager hash, legacy Windows authentication (DES-based)",
      ),

      # ── MySQL ──────────────────────────────────────────────────
      Pattern.new(
        name:        "MySQL 4.1+ (double SHA-1)",
        regex:       /\A\*[A-F0-9]{40}\z/,
        length:      41,
        category:    :database,
        description: "MySQL 4.1+ password hash - double SHA-1 with * prefix",
        confidence_base: :high,
      ),

      # ── Whirlpool ──────────────────────────────────────────────
      Pattern.new(
        name:        "Whirlpool",
        regex:       /\A[a-fA-F0-9]{128}\z/,
        length:      128,
        category:    :cryptographic,
        description: "Whirlpool - 512-bit digest (ISO/IEC 10118-3)",
      ),

      # ── Tiger ──────────────────────────────────────────────────
      Pattern.new(
        name:        "Tiger-192",
        regex:       /\A[a-fA-F0-9]{48}\z/,
        length:      48,
        category:    :cryptographic,
        description: "Tiger-192 - 192-bit digest optimized for 64-bit platforms",
      ),

      # ── GOST ───────────────────────────────────────────────────
      Pattern.new(
        name:        "GOST R 34.11-94",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :cryptographic,
        description: "GOST R 34.11-94 - Russian federal standard hash (256-bit)",
      ),
      Pattern.new(
        name:        "Streebog-256 (GOST R 34.11-2012)",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :cryptographic,
        description: "Streebog-256 - Russian federal standard hash (256-bit, RFC 6986)",
      ),
      Pattern.new(
        name:        "Streebog-512 (GOST R 34.11-2012)",
        regex:       /\A[a-fA-F0-9]{128}\z/,
        length:      128,
        category:    :cryptographic,
        description: "Streebog-512 - Russian federal standard hash (512-bit, RFC 6986)",
      ),

      # ── Snefru ─────────────────────────────────────────────────
      Pattern.new(
        name:        "Snefru-128",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :cryptographic,
        description: "Snefru-128 - 128-bit Merkle hash function",
      ),
      Pattern.new(
        name:        "Snefru-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :cryptographic,
        description: "Snefru-256 - 256-bit Merkle hash function",
      ),

      # ── HAVAL ──────────────────────────────────────────────────
      Pattern.new(
        name:        "HAVAL-128",
        regex:       /\A[a-fA-F0-9]{32}\z/,
        length:      32,
        category:    :cryptographic,
        description: "HAVAL-128 - 128-bit variable-length hash",
      ),
      Pattern.new(
        name:        "HAVAL-160",
        regex:       /\A[a-fA-F0-9]{40}\z/,
        length:      40,
        category:    :cryptographic,
        description: "HAVAL-160 - 160-bit variable-length hash",
      ),
      Pattern.new(
        name:        "HAVAL-192",
        regex:       /\A[a-fA-F0-9]{48}\z/,
        length:      48,
        category:    :cryptographic,
        description: "HAVAL-192 - 192-bit variable-length hash",
      ),
      Pattern.new(
        name:        "HAVAL-224",
        regex:       /\A[a-fA-F0-9]{56}\z/,
        length:      56,
        category:    :cryptographic,
        description: "HAVAL-224 - 224-bit variable-length hash",
      ),
      Pattern.new(
        name:        "HAVAL-256",
        regex:       /\A[a-fA-F0-9]{64}\z/,
        length:      64,
        category:    :cryptographic,
        description: "HAVAL-256 - 256-bit variable-length hash",
      ),
    ].freeze

    # Group patterns by hex output length for fast lookup.
    BY_HEX_LENGTH = DEFINITIONS.each_with_object({}) { |p, map|
      next unless p.length

      (map[p.length] ||= []) << p
    }.freeze

    # Patterns that match on prefix/structure rather than fixed length.
    STRUCTURED = DEFINITIONS.select { |p| p.length.nil? }.freeze
  end

  # Core detection engine.
  module Detector
    module_function

    # Identify possible hash algorithms for a given input string.
    # Returns an Array of Match objects sorted by confidence (high first).
    def identify(input)
      return [] if input.nil? || input.strip.empty?

      clean = input.strip
      matches = []

      # Check structured (prefix-based) patterns first — these are high-confidence.
      Patterns::STRUCTURED.each do |pattern|
        matches << pattern.build_match if pattern.match?(clean)
      end

      # Check fixed-length hex patterns.
      hex_len = clean.length
      candidates = Patterns::BY_HEX_LENGTH[hex_len]
      candidates&.each do |pattern|
        matches << pattern.build_match if pattern.match?(clean)
      end

      sort_matches(matches)
    end

    # Identify hashes in bulk. Accepts an Array of strings.
    # Returns a Hash mapping each input to its Array of Match objects.
    def identify_many(inputs)
      inputs.each_with_object({}) do |input, results|
        results[input] = identify(input)
      end
    end

    # Produce a human-readable report for a single hash.
    def report(input)
      matches = identify(input)
      lines = []
      lines << "Hash:    #{input}"
      lines << "Length:  #{input.strip.length} characters"
      lines << ""

      if matches.empty?
        lines << "No matching hash algorithms found."
      else
        lines << "Possible algorithms (#{matches.size} candidates):"
        lines << "-" * 60
        matches.each_with_index do |m, i|
          lines << "  #{i + 1}. #{m}"
        end
      end

      lines.join("\n")
    end

    # Produce a report for multiple hashes.
    def report_many(inputs)
      inputs.map { |input| report(input) }.join("\n#{"=" * 60}\n")
    end

    CONFIDENCE_ORDER = { high: 0, medium: 1, low: 2 }.freeze

    def sort_matches(matches)
      matches.sort_by { |m| CONFIDENCE_ORDER.fetch(m.confidence, 99) }
    end
    private_class_method :sort_matches
  end
end

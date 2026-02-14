# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require_relative "../hash_detector"

class HashDetectorIdentifyTest < Minitest::Test
  # ── Empty / nil input ──────────────────────────────────────
  def test_nil_returns_empty
    assert_equal [], HashDetector::Detector.identify(nil)
  end

  def test_empty_string_returns_empty
    assert_equal [], HashDetector::Detector.identify("")
  end

  def test_whitespace_returns_empty
    assert_equal [], HashDetector::Detector.identify("   ")
  end

  # ── MD5-length (32 hex chars) ──────────────────────────────
  def test_identifies_md5
    matches = HashDetector::Detector.identify("d41d8cd98f00b204e9800998ecf8427e")
    algos = matches.map(&:algorithm)
    assert_includes algos, "MD5"
  end

  def test_identifies_md4_ntlm_lm_for_32_hex
    matches = HashDetector::Detector.identify("d41d8cd98f00b204e9800998ecf8427e")
    algos = matches.map(&:algorithm)
    assert_includes algos, "MD4"
    assert_includes algos, "NTLM"
    assert_includes algos, "LM"
  end

  def test_md5_length_matches_have_hash_length_32
    matches = HashDetector::Detector.identify("d41d8cd98f00b204e9800998ecf8427e")
    matches.each do |m|
      assert_equal 32, m.hash_length
    end
  end

  # ── SHA-1-length (40 hex chars) ────────────────────────────
  def test_identifies_sha1
    matches = HashDetector::Detector.identify("da39a3ee5e6b4b0d3255bfef95601890afd80709")
    algos = matches.map(&:algorithm)
    assert_includes algos, "SHA-1"
  end

  def test_identifies_ripemd160
    matches = HashDetector::Detector.identify("da39a3ee5e6b4b0d3255bfef95601890afd80709")
    algos = matches.map(&:algorithm)
    assert_includes algos, "RIPEMD-160"
  end

  # ── SHA-256-length (64 hex chars) ──────────────────────────
  def test_identifies_sha256
    matches = HashDetector::Detector.identify("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    algos = matches.map(&:algorithm)
    assert_includes algos, "SHA-256"
  end

  def test_sha256_has_high_confidence
    matches = HashDetector::Detector.identify("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    sha256 = matches.find { |m| m.algorithm == "SHA-256" }
    assert_equal :high, sha256.confidence
  end

  def test_high_confidence_sorted_before_medium
    matches = HashDetector::Detector.identify("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    confidences = matches.map(&:confidence)
    last_high = confidences.rindex(:high)
    first_medium = confidences.index(:medium)
    assert_operator last_high, :<, first_medium if last_high && first_medium
  end

  # ── SHA-512-length (128 hex chars) ─────────────────────────
  def test_identifies_sha512
    hash = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce" \
           "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    matches = HashDetector::Detector.identify(hash)
    algos = matches.map(&:algorithm)
    assert_includes algos, "SHA-512"
    assert_includes algos, "BLAKE2b-512"
    assert_includes algos, "Whirlpool"
  end

  # ── bcrypt ─────────────────────────────────────────────────
  def test_identifies_bcrypt
    matches = HashDetector::Detector.identify("$2b$12$WApznUPhDubN0oeveSXHp.Rl5eS13BwV0HDmEAJVSWnOaF3DkK/Fi")
    assert_equal 1, matches.size
    assert_equal "bcrypt", matches.first.algorithm
    assert_equal :high, matches.first.confidence
    assert_equal :password, matches.first.category
  end

  # ── Argon2 ─────────────────────────────────────────────────
  def test_identifies_argon2
    matches = HashDetector::Detector.identify("$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$hash")
    assert_equal 1, matches.size
    assert_equal "Argon2", matches.first.algorithm
    assert_equal :high, matches.first.confidence
  end

  # ── scrypt ─────────────────────────────────────────────────
  def test_identifies_scrypt
    matches = HashDetector::Detector.identify("$scrypt$ln=15,r=8,p=1$aGVsbG8$hash")
    assert_equal 1, matches.size
    assert_equal "scrypt", matches.first.algorithm
  end

  # ── PBKDF2 ─────────────────────────────────────────────────
  def test_identifies_pbkdf2_sha256
    matches = HashDetector::Detector.identify("$pbkdf2-sha256$29000$salt$hash")
    algos = matches.map(&:algorithm)
    assert_includes algos, "PBKDF2-SHA256"
  end

  # ── Unix crypt ─────────────────────────────────────────────
  def test_identifies_md5_crypt
    matches = HashDetector::Detector.identify("$1$salt1234$yP/kYFGmJqGLadTojTkSy0")
    assert_equal "MD5-crypt", matches.first.algorithm
  end

  def test_identifies_sha512_crypt
    hash = "$6$rounds=5000$saltsalt$" + "a" * 86
    matches = HashDetector::Detector.identify(hash)
    algos = matches.map(&:algorithm)
    assert_includes algos, "SHA-512-crypt"
  end

  # ── MySQL ──────────────────────────────────────────────────
  def test_identifies_mysql_hash
    matches = HashDetector::Detector.identify("*6C8989366EAF6BCBBF727DEFF3B77E56AC43370F")
    assert_equal "MySQL 4.1+ (double SHA-1)", matches.first.algorithm
    assert_equal :high, matches.first.confidence
  end

  # ── CRC-32 ─────────────────────────────────────────────────
  def test_identifies_crc32
    matches = HashDetector::Detector.identify("3610a686")
    algos = matches.map(&:algorithm)
    assert_includes algos, "CRC-32"
  end

  # ── SHA-384 (96 hex chars) ─────────────────────────────────
  def test_identifies_sha384
    hash = "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"
    matches = HashDetector::Detector.identify(hash)
    algos = matches.map(&:algorithm)
    assert_includes algos, "SHA-384"
  end

  # ── Non-hex / invalid input ────────────────────────────────
  def test_non_hex_returns_empty
    assert_equal [], HashDetector::Detector.identify("not_a_hash_at_all!")
  end

  def test_mixed_content_returns_empty
    assert_equal [], HashDetector::Detector.identify("hello world 12345")
  end

  # ── Whitespace handling ────────────────────────────────────
  def test_strips_whitespace
    matches = HashDetector::Detector.identify("  d41d8cd98f00b204e9800998ecf8427e  ")
    algos = matches.map(&:algorithm)
    assert_includes algos, "MD5"
  end
end

class HashDetectorIdentifyManyTest < Minitest::Test
  def test_returns_results_for_each_hash
    hashes = [
      "d41d8cd98f00b204e9800998ecf8427e",
      "da39a3ee5e6b4b0d3255bfef95601890afd80709",
    ]
    results = HashDetector::Detector.identify_many(hashes)
    assert_equal hashes, results.keys
    assert_includes results[hashes[0]].map(&:algorithm), "MD5"
    assert_includes results[hashes[1]].map(&:algorithm), "SHA-1"
  end
end

class HashDetectorReportTest < Minitest::Test
  def test_report_includes_hash_info
    report = HashDetector::Detector.report("d41d8cd98f00b204e9800998ecf8427e")
    assert_match(/Hash:/, report)
    assert_match(/Length:/, report)
    assert_match(/Possible algorithms/, report)
    assert_match(/MD5/, report)
  end

  def test_report_handles_unrecognized_input
    report = HashDetector::Detector.report("xyz")
    assert_match(/No matching hash algorithms found/, report)
  end

  def test_report_many_includes_dividers
    hashes = [
      "d41d8cd98f00b204e9800998ecf8427e",
      "da39a3ee5e6b4b0d3255bfef95601890afd80709",
    ]
    report = HashDetector::Detector.report_many(hashes)
    assert_match(/MD5/, report)
    assert_match(/SHA-1/, report)
    assert_includes report, "=" * 60
  end
end

class HashDetectorMatchTest < Minitest::Test
  def setup
    @match = HashDetector::Match.new(
      algorithm:   "SHA-256",
      hash_length: 64,
      confidence:  :high,
      category:    :sha,
      description: "test description",
    )
  end

  def test_to_h
    h = @match.to_h
    assert_equal "SHA-256", h[:algorithm]
    assert_equal 64, h[:hash_length]
    assert_equal :high, h[:confidence]
    assert_equal :sha, h[:category]
  end

  def test_to_s
    s = @match.to_s
    assert_includes s, "SHA-256"
    assert_includes s, "sha"
    assert_includes s, "high"
  end
end

class HashDetectorPatternTest < Minitest::Test
  def setup
    @pattern = HashDetector::Pattern.new(
      name:        "TestHash",
      regex:       /\A[a-fA-F0-9]{32}\z/,
      length:      32,
      category:    :test,
      description: "test pattern",
    )
  end

  def test_matches_valid_hex
    assert @pattern.match?("d41d8cd98f00b204e9800998ecf8427e")
  end

  def test_rejects_wrong_length
    refute @pattern.match?("d41d8cd98f00b204")
  end

  def test_rejects_non_hex
    refute @pattern.match?("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
  end
end

class HashDetectorPatternsTest < Minitest::Test
  def test_by_hex_length_is_populated
    assert_instance_of Hash, HashDetector::Patterns::BY_HEX_LENGTH
    refute_empty HashDetector::Patterns::BY_HEX_LENGTH[32]
    refute_empty HashDetector::Patterns::BY_HEX_LENGTH[64]
  end

  def test_structured_patterns_include_password_hashes
    names = HashDetector::Patterns::STRUCTURED.map(&:name)
    assert_includes names, "Argon2"
    assert_includes names, "scrypt"
  end

  def test_covers_major_hash_families
    categories = HashDetector::Patterns::DEFINITIONS.map(&:category).uniq
    assert_includes categories, :sha
    assert_includes categories, :sha3
    assert_includes categories, :blake
    assert_includes categories, :message_digest
    assert_includes categories, :password
    assert_includes categories, :checksum
  end
end

#!/usr/bin/env python3
"""
Tests for the Hydra Emoji Smuggling Toolkit.
Verifies all four encoding methods roundtrip correctly and
the detector identifies smuggled content.
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lib.zwc_smuggler import ZWCSmuggler
from lib.variation_steg import VariationSteg
from lib.emoji_cipher import EmojiCipher
from lib.regional_encoder import RegionalEncoder
from lib.detector import Detector


class TestZWCSmuggler(unittest.TestCase):
    """Tests for Head 1: Zero-Width Character Smuggling."""

    def test_roundtrip_ascii(self):
        secret = "Hello, World!"
        encoded = ZWCSmuggler.encode(secret)
        decoded = ZWCSmuggler.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_unicode(self):
        secret = "Unicode: cafe\u0301 \u00f1 \u00fc"
        encoded = ZWCSmuggler.encode(secret)
        decoded = ZWCSmuggler.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_empty_ish(self):
        secret = "a"
        encoded = ZWCSmuggler.encode(secret)
        decoded = ZWCSmuggler.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_custom_cover(self):
        secret = "test"
        cover = "\U0001F680\U0001F681\U0001F682\U0001F683\U0001F684"
        encoded = ZWCSmuggler.encode(secret, cover_emojis=cover)
        decoded = ZWCSmuggler.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_decode_no_payload_raises(self):
        with self.assertRaises(ValueError):
            ZWCSmuggler.decode("just normal text")

    def test_analysis_detects_payload(self):
        encoded = ZWCSmuggler.encode("secret")
        analysis = ZWCSmuggler.analyze(encoded)
        self.assertTrue(analysis['likely_payload'])
        self.assertTrue(analysis['zwc_present'])

    def test_analysis_clean_text(self):
        analysis = ZWCSmuggler.analyze("just emojis \U0001F600\U0001F601")
        self.assertFalse(analysis['likely_payload'])


class TestVariationSteg(unittest.TestCase):
    """Tests for Head 2: Variation Selector Steganography."""

    def test_roundtrip_ascii(self):
        secret = "Hello, World!"
        encoded = VariationSteg.encode(secret)
        decoded = VariationSteg.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_unicode(self):
        secret = "Greetings from Python 3!"
        encoded = VariationSteg.encode(secret)
        decoded = VariationSteg.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_bytes_edge(self):
        # Test bytes with high/low nibbles at boundaries
        secret = "\x01\x0f\xf0\xff".encode('latin-1').decode('latin-1')
        encoded = VariationSteg.encode(secret)
        decoded = VariationSteg.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_decode_no_vs_raises(self):
        with self.assertRaises(ValueError):
            VariationSteg.decode("normal text \U0001F600")

    def test_analysis_detects_payload(self):
        encoded = VariationSteg.encode("test data")
        analysis = VariationSteg.analyze(encoded)
        self.assertTrue(analysis['suspicious'])
        self.assertGreater(analysis['total_vs_chars'], 0)


class TestEmojiCipher(unittest.TestCase):
    """Tests for Head 3: Emoji Substitution Cipher."""

    def test_roundtrip_default_key(self):
        cipher = EmojiCipher(key=42)
        secret = "Hello, World!"
        encoded = cipher.encode(secret)
        decoded = cipher.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_custom_key(self):
        cipher = EmojiCipher(key=12345)
        secret = "Custom key test"
        encoded = cipher.encode(secret)
        decoded = cipher.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_wrong_key_fails(self):
        encoder = EmojiCipher(key=42)
        decoder = EmojiCipher(key=99)
        encoded = encoder.encode("secret")
        decoded = decoder.decode(encoded)
        # Wrong key produces garbage, not the original
        self.assertNotEqual(decoded, "secret")

    def test_noise_roundtrip(self):
        cipher = EmojiCipher(key=42)
        secret = "Noisy message"
        encoded = cipher.encode(secret, noise_ratio=0.5)
        decoded = cipher.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_different_keys_different_output(self):
        c1 = EmojiCipher(key=1)
        c2 = EmojiCipher(key=2)
        secret = "same input"
        e1 = c1.encode(secret)
        e2 = c2.encode(secret)
        self.assertNotEqual(e1, e2)


class TestRegionalEncoder(unittest.TestCase):
    """Tests for Head 4: Regional Indicator Encoding."""

    def test_roundtrip_ascii(self):
        secret = "Hello, World!"
        encoded = RegionalEncoder.encode(secret)
        decoded = RegionalEncoder.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_short(self):
        secret = "Hi"
        encoded = RegionalEncoder.encode(secret)
        decoded = RegionalEncoder.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_roundtrip_unicode(self):
        secret = "Python rocks!"
        encoded = RegionalEncoder.encode(secret)
        decoded = RegionalEncoder.decode(encoded)
        self.assertEqual(decoded, secret)

    def test_decode_insufficient_raises(self):
        with self.assertRaises(ValueError):
            RegionalEncoder.decode("no regional indicators here")

    def test_analysis_detects_payload(self):
        encoded = RegionalEncoder.encode("test message here")
        analysis = RegionalEncoder.analyze(encoded)
        self.assertTrue(analysis['ri_present'])
        self.assertGreater(analysis['total_ri_chars'], 0)


class TestDetector(unittest.TestCase):
    """Tests for the defensive Detector module."""

    def setUp(self):
        self.detector = Detector()

    def test_clean_text(self):
        result = self.detector.scan("Just a normal message \U0001F600")
        self.assertEqual(result['threat_level'], 'CLEAN')
        self.assertEqual(len(result['methods_detected']), 0)

    def test_detects_zwc(self):
        smuggled = ZWCSmuggler.encode("hidden data")
        result = self.detector.scan(smuggled, verbose=True)
        self.assertIn('ZWC Smuggling (Head 1)', result['methods_detected'])
        self.assertNotEqual(result['threat_level'], 'CLEAN')

    def test_detects_variation_selectors(self):
        smuggled = VariationSteg.encode("hidden data")
        result = self.detector.scan(smuggled, verbose=True)
        self.assertIn('Variation Selector Steg (Head 2)', result['methods_detected'])

    def test_detects_regional_indicators(self):
        smuggled = RegionalEncoder.encode("hidden data in flags")
        result = self.detector.scan(smuggled, verbose=True)
        self.assertIn('Regional Indicator Encoding (Head 4)', result['methods_detected'])

    def test_invisible_ratio(self):
        smuggled = ZWCSmuggler.encode("data")
        result = self.detector.scan(smuggled)
        self.assertGreater(result['invisible_ratio'], 0)

    def test_hexdump(self):
        dump = self.detector.hexdump("ABC")
        self.assertIn('41 42 43', dump)

    def test_codepoint_dump(self):
        dump = self.detector.codepoint_dump("A\u200b")
        self.assertIn('U+000041', dump)
        self.assertIn('INVISIBLE', dump)


if __name__ == '__main__':
    unittest.main(verbosity=2)

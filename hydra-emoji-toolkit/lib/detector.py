"""
Hydra Detector - Defensive Analysis Module
============================================
Scans text for signs of emoji-based steganography across all four
smuggling techniques.  Designed for blue-team / defensive training.

Use this to learn how to detect covert channels hidden in emoji text.
"""

from __future__ import annotations

import json

from .core import (
    ZWC_ZERO, ZWC_ONE, ZWC_SEP, ZWC_MARK,
    VARIATION_SELECTORS, REGIONAL_INDICATORS,
)


class Detector:
    """Multi-method detector for emoji steganography."""

    DESCRIPTION = "Defensive Steganography Detector"

    def scan(self, text: str, verbose: bool = False) -> dict:
        """
        Perform a comprehensive scan of *text* for all known smuggling methods.

        Parameters
        ----------
        text : str
            The suspect text to analyze.
        verbose : bool
            Include detailed per-method breakdowns.

        Returns
        -------
        dict
            Scan results with threat assessment.
        """
        results = {
            'input_length': len(text),
            'visible_length': len(self._strip_invisible(text)),
            'invisible_chars': len(text) - len(self._strip_invisible(text)),
            'methods_detected': [],
            'threat_level': 'CLEAN',
            'details': {},
        }

        # Run each detection method
        zwc = self._detect_zwc(text)
        vs = self._detect_variation_selectors(text)
        ri = self._detect_regional_indicators(text)
        entropy = self._analyze_emoji_entropy(text)

        if verbose:
            results['details'] = {
                'zero_width': zwc,
                'variation_selectors': vs,
                'regional_indicators': ri,
                'emoji_entropy': entropy,
            }

        # Determine detections
        if zwc['likely_payload']:
            results['methods_detected'].append('ZWC Smuggling (Head 1)')
        if vs['suspicious']:
            results['methods_detected'].append('Variation Selector Steg (Head 2)')
        if ri['suspicious']:
            results['methods_detected'].append('Regional Indicator Encoding (Head 4)')
        if entropy['suspicious']:
            results['methods_detected'].append('Emoji Cipher (Head 3) - possible')

        # Threat level
        n = len(results['methods_detected'])
        if n == 0:
            results['threat_level'] = 'CLEAN'
        elif n == 1:
            results['threat_level'] = 'LOW'
        elif n == 2:
            results['threat_level'] = 'MEDIUM'
        else:
            results['threat_level'] = 'HIGH'

        # Add invisible character ratio
        if results['input_length'] > 0:
            results['invisible_ratio'] = round(
                results['invisible_chars'] / results['input_length'], 4
            )
        else:
            results['invisible_ratio'] = 0.0

        return results

    def hexdump(self, text: str) -> str:
        """
        Produce a hex dump of the text showing all Unicode codepoints.

        Useful for visually identifying hidden characters in training.
        """
        lines = []
        encoded = text.encode('utf-8')
        for i in range(0, len(encoded), 16):
            chunk = encoded[i:i + 16]
            hex_part = ' '.join(f'{b:02x}' for b in chunk)
            # Show printable ASCII and mark non-printable
            ascii_part = ''.join(
                chr(b) if 32 <= b < 127 else '.'
                for b in chunk
            )
            lines.append(f'{i:08x}  {hex_part:<48s}  |{ascii_part}|')
        return '\n'.join(lines)

    def codepoint_dump(self, text: str) -> str:
        """
        Show each character with its Unicode codepoint and name.

        Invaluable for training - makes invisible characters visible.
        """
        import unicodedata
        lines = []
        for i, ch in enumerate(text):
            cp = ord(ch)
            try:
                name = unicodedata.name(ch)
            except ValueError:
                name = '<unknown>'

            visibility = 'VISIBLE' if self._is_visible(ch) else 'INVISIBLE'
            lines.append(
                f'[{i:4d}] U+{cp:06X}  {visibility:9s}  {name}'
            )
        return '\n'.join(lines)

    # ── Private helpers ───────────────────────────────────────────────

    @staticmethod
    def _strip_invisible(text: str) -> str:
        """Remove zero-width and other invisible characters."""
        invisible = {ZWC_ZERO, ZWC_ONE, ZWC_SEP, ZWC_MARK}
        invisible.update(VARIATION_SELECTORS)
        return ''.join(c for c in text if c not in invisible)

    @staticmethod
    def _is_visible(ch: str) -> bool:
        invisible = {ZWC_ZERO, ZWC_ONE, ZWC_SEP, ZWC_MARK}
        invisible.update(VARIATION_SELECTORS)
        return ch not in invisible and ord(ch) >= 32

    @staticmethod
    def _detect_zwc(text: str) -> dict:
        counts = {
            'U+200B': text.count(ZWC_ZERO),
            'U+200C': text.count(ZWC_ONE),
            'U+200D': text.count(ZWC_SEP),
            'U+FEFF': text.count(ZWC_MARK),
        }
        total = sum(counts.values())
        return {
            'total': total,
            'breakdown': counts,
            'likely_payload': counts['U+FEFF'] >= 2,
            'suspicious': total > 2,
        }

    @staticmethod
    def _detect_variation_selectors(text: str) -> dict:
        vs_set = set(VARIATION_SELECTORS)
        count = sum(1 for c in text if c in vs_set)
        return {
            'total': count,
            'suspicious': count > 2,
            'estimated_bytes': count // 2,
        }

    @staticmethod
    def _detect_regional_indicators(text: str) -> dict:
        ri_set = set(REGIONAL_INDICATORS)
        count = sum(1 for c in text if c in ri_set)
        return {
            'total': count,
            'suspicious': count > 10,
            'potential_flags': count // 2,
        }

    @staticmethod
    def _analyze_emoji_entropy(text: str) -> dict:
        """Check if emoji distribution suggests a cipher."""
        emojis = [c for c in text if ord(c) > 0x1F000]
        if not emojis:
            return {'emoji_count': 0, 'suspicious': False}

        # Count unique vs total - cipher text tends to have more variety
        unique = len(set(emojis))
        ratio = unique / len(emojis) if emojis else 0

        return {
            'emoji_count': len(emojis),
            'unique_emojis': unique,
            'diversity_ratio': round(ratio, 4),
            'suspicious': len(emojis) > 10 and ratio > 0.6,
        }

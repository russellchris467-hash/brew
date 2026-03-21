"""
Head 4 - Regional Indicator Encoding
======================================
Uses Unicode Regional Indicator Symbols (U+1F1E6 - U+1F1FF) to encode
data.  There are 26 regional indicators (A-Z), so we encode in base-26.

How it works:
  1. Convert secret to bytes.
  2. Encode the byte stream as a base-26 number using regional indicators.
  3. Pairs of regional indicators render as flag emojis in many clients,
     so the output looks like a string of country flags.

Detection difficulty: MEDIUM - a string of many flag emojis may look odd
but is plausible in international contexts.  Statistical analysis of which
"countries" appear reveals non-geographic patterns.
"""

from __future__ import annotations

from .core import REGIONAL_INDICATORS


class RegionalEncoder:
    """Encode/decode secrets using Regional Indicator symbols (flag emojis)."""

    METHOD_NAME = "regional"
    DESCRIPTION = "Regional Indicator Encoding"

    # ── Encoding ──────────────────────────────────────────────────────

    @staticmethod
    def encode(secret: str) -> str:
        """
        Encode *secret* as a sequence of regional indicator symbols.

        The byte stream is converted to a base-26 big-integer
        representation, where each "digit" is a regional indicator A-Z.
        A length prefix (2 regional indicators) is prepended so the
        decoder knows the original byte count.

        Parameters
        ----------
        secret : str
            Plaintext to encode.

        Returns
        -------
        str
            String of regional indicator symbols (renders as flags).
        """
        data = secret.encode('utf-8')
        data_len = len(data)

        # Convert bytes to big integer
        num = int.from_bytes(data, byteorder='big')

        # Convert to base-26 digits
        digits: list[int] = []
        if num == 0:
            digits = [0]
        else:
            while num > 0:
                digits.append(num % 26)
                num //= 26
            digits.reverse()

        # Length prefix: encode data_len as two base-26 digits
        # Max supported: 26*26 - 1 = 675 bytes
        len_high = data_len // 26
        len_low = data_len % 26

        # Build output
        indicators = [REGIONAL_INDICATORS[len_high], REGIONAL_INDICATORS[len_low]]
        for d in digits:
            indicators.append(REGIONAL_INDICATORS[d])

        return ''.join(indicators)

    # ── Decoding ──────────────────────────────────────────────────────

    @staticmethod
    def decode(smuggled: str) -> str:
        """
        Decode regional-indicator-encoded text.

        Parameters
        ----------
        smuggled : str
            String of regional indicator symbols.

        Returns
        -------
        str
            Decoded plaintext.

        Raises
        ------
        ValueError
            If input contains insufficient regional indicators.
        """
        ri_set = set(REGIONAL_INDICATORS)

        # Extract only regional indicator characters
        ri_chars = [c for c in smuggled if c in ri_set]

        if len(ri_chars) < 3:
            raise ValueError(
                "Need at least 3 regional indicators (2 length + 1 data)."
            )

        # Decode length prefix
        len_high = REGIONAL_INDICATORS.index(ri_chars[0])
        len_low = REGIONAL_INDICATORS.index(ri_chars[1])
        expected_len = len_high * 26 + len_low

        # Decode base-26 digits to big integer
        digits = [REGIONAL_INDICATORS.index(c) for c in ri_chars[2:]]
        num = 0
        for d in digits:
            num = num * 26 + d

        # Convert back to bytes
        raw = num.to_bytes(expected_len, byteorder='big')
        return raw.decode('utf-8')

    # ── Analysis ──────────────────────────────────────────────────────

    @staticmethod
    def analyze(text: str) -> dict:
        """Analyze text for regional indicator usage patterns."""
        ri_set = set(REGIONAL_INDICATORS)
        ri_chars = [c for c in text if c in ri_set]

        # Check letter distribution
        freq: dict[str, int] = {}
        for c in ri_chars:
            idx = REGIONAL_INDICATORS.index(c)
            letter = chr(ord('A') + idx)
            freq[letter] = freq.get(letter, 0) + 1

        # Flag emojis are pairs; count potential flags
        flag_pairs = len(ri_chars) // 2

        return {
            'method': 'Regional Indicator Analysis',
            'ri_present': len(ri_chars) > 0,
            'total_ri_chars': len(ri_chars),
            'potential_flags': flag_pairs,
            'letter_frequency': freq,
            'suspicious': len(ri_chars) > 10,
            'non_geographic_pattern': len(freq) > 15,  # uses many "countries"
        }

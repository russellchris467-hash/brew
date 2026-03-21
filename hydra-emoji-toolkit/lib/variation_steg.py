"""
Head 2 - Variation Selector Steganography
==========================================
Hides data by appending invisible Unicode Variation Selectors (VS1-VS16)
after each carrier emoji.  Since there are 16 selectors, each emoji can
carry a 4-bit nibble (0-15), meaning two emojis encode one full byte.

How it works:
  1. Convert the secret to bytes.
  2. Split each byte into two 4-bit nibbles (high, low).
  3. For each nibble, pick a carrier emoji and append VS{nibble+1}.
  4. The variation selector is invisible in most renderers.

Detection difficulty: MEDIUM - variation selectors are legitimate Unicode
but unusual on emojis that don't have registered glyph variants.
Defenders can scan for unexpected VS usage.
"""

from __future__ import annotations

import random

from .core import VARIATION_SELECTORS, CARRIER_EMOJIS


class VariationSteg:
    """Encode/decode secrets using Variation Selectors on emojis."""

    METHOD_NAME = "vs"
    DESCRIPTION = "Variation Selector Steganography"

    # ── Encoding ──────────────────────────────────────────────────────

    @staticmethod
    def encode(secret: str, cover_emojis: str | None = None) -> str:
        """
        Hide *secret* by appending variation selectors to emojis.

        Each emoji carries 4 bits (one nibble).  Two emojis = one byte.

        Parameters
        ----------
        secret : str
            The plaintext to hide.
        cover_emojis : str, optional
            Emojis to use as carriers.  Auto-generated if not given.

        Returns
        -------
        str
            Emoji string with variation-selector payload.
        """
        data = secret.encode('utf-8')
        nibbles: list[int] = []
        for byte in data:
            nibbles.append((byte >> 4) & 0x0F)  # high nibble
            nibbles.append(byte & 0x0F)          # low nibble

        # Build carrier list
        if cover_emojis:
            emojis = list(cover_emojis)
        else:
            emojis = []

        while len(emojis) < len(nibbles):
            emojis.append(random.choice(CARRIER_EMOJIS))

        # Encode: emoji + variation selector for each nibble
        result: list[str] = []
        for i, nibble in enumerate(nibbles):
            result.append(emojis[i])
            result.append(VARIATION_SELECTORS[nibble])

        # Append any leftover emojis as-is (camouflage padding)
        for e in emojis[len(nibbles):]:
            result.append(e)

        return ''.join(result)

    # ── Decoding ──────────────────────────────────────────────────────

    @staticmethod
    def decode(smuggled: str) -> str:
        """
        Extract a secret encoded with variation selectors.

        Parameters
        ----------
        smuggled : str
            The emoji string with VS-encoded payload.

        Returns
        -------
        str
            The decoded secret.

        Raises
        ------
        ValueError
            If an odd number of nibbles is found or decoding fails.
        """
        vs_set = set(VARIATION_SELECTORS)

        nibbles: list[int] = []
        for ch in smuggled:
            if ch in vs_set:
                nibbles.append(VARIATION_SELECTORS.index(ch))

        if len(nibbles) == 0:
            raise ValueError("No variation selectors found in input.")

        if len(nibbles) % 2 != 0:
            raise ValueError(
                f"Odd number of nibbles ({len(nibbles)}); "
                "expected pairs for full bytes."
            )

        # Reconstruct bytes from nibble pairs
        decoded_bytes = bytearray()
        for i in range(0, len(nibbles), 2):
            byte_val = (nibbles[i] << 4) | nibbles[i + 1]
            decoded_bytes.append(byte_val)

        return decoded_bytes.decode('utf-8')

    # ── Analysis ──────────────────────────────────────────────────────

    @staticmethod
    def analyze(text: str) -> dict:
        """Return statistics about variation selector usage."""
        vs_set = set(VARIATION_SELECTORS)
        found = [c for c in text if c in vs_set]
        vs_distribution = {}
        for c in found:
            idx = VARIATION_SELECTORS.index(c)
            label = f'VS{idx + 1} (U+FE0{idx:X})'
            vs_distribution[label] = vs_distribution.get(label, 0) + 1

        return {
            'method': 'Variation Selector Analysis',
            'vs_present': len(found) > 0,
            'total_vs_chars': len(found),
            'distribution': vs_distribution,
            'suspicious': len(found) > 2,
            'estimated_payload_bytes': len(found) // 2,
        }

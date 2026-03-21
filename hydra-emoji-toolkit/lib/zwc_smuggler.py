"""
Head 1 - Zero-Width Character Smuggler
=======================================
Hides arbitrary text inside an innocent-looking emoji string by
inserting invisible zero-width Unicode characters between visible emojis.

How it works:
  1. Convert the secret message to binary (UTF-8 bytes -> bits).
  2. Map each bit to an invisible zero-width character:
       '0' -> U+200B (ZERO WIDTH SPACE)
       '1' -> U+200C (ZERO WIDTH NON-JOINER)
  3. Separate each byte with U+200D (ZERO WIDTH JOINER).
  4. Wrap the payload with U+FEFF (BOM) boundary markers.
  5. Interleave the invisible payload between visible carrier emojis.

The result looks like a normal emoji string but contains hidden data.

Detection difficulty: LOW - any hex dump or zero-width character scanner
will reveal the hidden data. This is the simplest smuggling technique.
"""

from __future__ import annotations

import random

from .core import (
    ZWC_ZERO, ZWC_ONE, ZWC_SEP, ZWC_MARK,
    CARRIER_EMOJIS, text_to_bits, bits_to_text,
)


class ZWCSmuggler:
    """Encode/decode secrets using zero-width characters between emojis."""

    METHOD_NAME = "zwc"
    DESCRIPTION = "Zero-Width Character Smuggling"

    # ── Encoding ──────────────────────────────────────────────────────

    @staticmethod
    def encode(secret: str, cover_emojis: str | None = None) -> str:
        """
        Hide *secret* inside a string of emojis.

        Parameters
        ----------
        secret : str
            The plaintext message to hide.
        cover_emojis : str, optional
            Visible emoji string to use as a carrier.  If not provided a
            random sequence is generated.

        Returns
        -------
        str
            An innocent-looking emoji string with embedded zero-width payload.
        """
        bits = text_to_bits(secret)

        # Build invisible payload
        payload_chars: list[str] = [ZWC_MARK]  # start boundary
        for i, byte_bits in enumerate(bits):
            for bit in byte_bits:
                payload_chars.append(ZWC_ONE if bit == '1' else ZWC_ZERO)
            if i < len(bits) - 1:
                payload_chars.append(ZWC_SEP)  # byte separator
        payload_chars.append(ZWC_MARK)  # end boundary

        # Build or parse the cover emoji list
        if cover_emojis is None:
            num_emojis = max(len(payload_chars) + 2, 6)
            emojis = [random.choice(CARRIER_EMOJIS) for _ in range(num_emojis)]
        else:
            emojis = list(cover_emojis)
            # Ensure enough carrier characters
            while len(emojis) < len(payload_chars) + 2:
                emojis.append(random.choice(CARRIER_EMOJIS))

        # Interleave: place invisible chars between visible emojis
        result: list[str] = [emojis[0]]
        for idx, zwc in enumerate(payload_chars):
            result.append(zwc)
            result.append(emojis[idx + 1])
        # Append remaining emojis
        for e in emojis[len(payload_chars) + 1:]:
            result.append(e)

        return ''.join(result)

    # ── Decoding ──────────────────────────────────────────────────────

    @staticmethod
    def decode(smuggled: str) -> str:
        """
        Extract a hidden message from a ZWC-smuggled emoji string.

        Parameters
        ----------
        smuggled : str
            The emoji string containing hidden zero-width characters.

        Returns
        -------
        str
            The decoded secret message.

        Raises
        ------
        ValueError
            If no valid ZWC payload is found.
        """
        # Extract only zero-width characters
        zwc_chars = [c for c in smuggled if c in (ZWC_ZERO, ZWC_ONE, ZWC_SEP, ZWC_MARK)]

        # Find boundaries
        try:
            start = zwc_chars.index(ZWC_MARK)
            end = zwc_chars.index(ZWC_MARK, start + 1)
        except ValueError:
            raise ValueError(
                "No ZWC boundary markers found. "
                "This string may not contain a ZWC-smuggled payload."
            )

        payload = zwc_chars[start + 1 : end]

        # Split by byte separator and reconstruct bits
        byte_strings: list[str] = []
        current_byte = []
        for c in payload:
            if c == ZWC_SEP:
                byte_strings.append(''.join(current_byte))
                current_byte = []
            elif c == ZWC_ZERO:
                current_byte.append('0')
            elif c == ZWC_ONE:
                current_byte.append('1')
        if current_byte:
            byte_strings.append(''.join(current_byte))

        return bits_to_text(byte_strings)

    # ── Analysis (for defensive training) ─────────────────────────────

    @staticmethod
    def analyze(text: str) -> dict:
        """Return statistics about zero-width characters in the text."""
        counts = {
            'zwc_space (U+200B)': text.count(ZWC_ZERO),
            'zwc_non_joiner (U+200C)': text.count(ZWC_ONE),
            'zwc_joiner (U+200D)': text.count(ZWC_SEP),
            'bom (U+FEFF)': text.count(ZWC_MARK),
        }
        total = sum(counts.values())
        return {
            'method': 'Zero-Width Character Analysis',
            'zwc_present': total > 0,
            'total_zwc_chars': total,
            'breakdown': counts,
            'suspicious': total > 2,
            'likely_payload': counts['bom (U+FEFF)'] >= 2,
        }

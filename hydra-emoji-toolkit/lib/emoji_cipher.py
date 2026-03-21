"""
Head 3 - Emoji Substitution Cipher
====================================
Maps each byte value (0-255) to a unique emoji, then encodes the secret
as a sequence of those emojis.  The result looks like a random collection
of emojis but actually encodes a byte stream.

How it works:
  1. Build a shuffled mapping of byte values (0-255) to 256 distinct emojis.
  2. Convert secret to UTF-8 bytes.
  3. Replace each byte with its mapped emoji.
  4. Optionally mix in "noise" emojis from outside the mapping.

Detection difficulty: HIGH without the key - the output is valid emoji
text.  However, statistical analysis may reveal non-random distribution
patterns compared to organic emoji usage.

A shared key (integer seed) is required for both encoding and decoding.
"""

from __future__ import annotations

import random


# Build a large pool of emojis covering multiple Unicode blocks
def _build_emoji_pool() -> list[str]:
    """Build a pool of 512+ distinct emoji codepoints."""
    pool = []
    # Emoticons (U+1F600 - U+1F64F)
    pool.extend(chr(c) for c in range(0x1F600, 0x1F650))
    # Misc symbols (U+1F300 - U+1F5FF) - subset
    pool.extend(chr(c) for c in range(0x1F300, 0x1F3F0))
    # Transport/map (U+1F680 - U+1F6FF)
    pool.extend(chr(c) for c in range(0x1F680, 0x1F700))
    # Supplemental symbols (U+1F900 - U+1F9FF)
    pool.extend(chr(c) for c in range(0x1F900, 0x1FA00))
    # Food & drink, animals, etc. (U+1F400 - U+1F4FF)
    pool.extend(chr(c) for c in range(0x1F400, 0x1F500))
    return pool


EMOJI_POOL = _build_emoji_pool()


class EmojiCipher:
    """Encode/decode secrets using an emoji substitution cipher."""

    METHOD_NAME = "cipher"
    DESCRIPTION = "Emoji Substitution Cipher"

    def __init__(self, key: int = 42):
        """
        Initialize the cipher with a numeric key.

        Parameters
        ----------
        key : int
            Seed for the PRNG that generates the byte-to-emoji mapping.
            Both sender and receiver must use the same key.
        """
        self.key = key
        self._mapping, self._reverse = self._build_mapping(key)

    @staticmethod
    def _build_mapping(key: int) -> tuple[dict[int, str], dict[str, int]]:
        """Create a deterministic byte <-> emoji mapping from the key."""
        rng = random.Random(key)
        pool = EMOJI_POOL.copy()
        rng.shuffle(pool)
        # Take first 256 for our byte mapping
        selected = pool[:256]
        forward = {i: selected[i] for i in range(256)}
        reverse = {selected[i]: i for i in range(256)}
        return forward, reverse

    # ── Encoding ──────────────────────────────────────────────────────

    def encode(self, secret: str, noise_ratio: float = 0.0) -> str:
        """
        Encode *secret* as a sequence of emojis.

        Parameters
        ----------
        secret : str
            Plaintext message.
        noise_ratio : float
            Fraction of noise emojis to inject (0.0 = none, 0.5 = 50%).
            Noise emojis are drawn from outside the cipher mapping.

        Returns
        -------
        str
            Emoji-encoded ciphertext.
        """
        data = secret.encode('utf-8')
        result = [self._mapping[b] for b in data]

        if noise_ratio > 0:
            # Noise emojis are ones NOT in our mapping
            mapped_set = set(self._mapping.values())
            noise_pool = [e for e in EMOJI_POOL if e not in mapped_set]
            if noise_pool:
                rng = random.Random()
                num_noise = int(len(result) * noise_ratio)
                for _ in range(num_noise):
                    pos = rng.randint(0, len(result))
                    result.insert(pos, rng.choice(noise_pool))

        return ''.join(result)

    # ── Decoding ──────────────────────────────────────────────────────

    def decode(self, smuggled: str) -> str:
        """
        Decode an emoji-cipher message, ignoring unknown emojis (noise).

        Parameters
        ----------
        smuggled : str
            The emoji-encoded ciphertext.

        Returns
        -------
        str
            Decoded plaintext.
        """
        decoded_bytes = bytearray()
        for ch in smuggled:
            if ch in self._reverse:
                decoded_bytes.append(self._reverse[ch])
            # Unknown emojis (noise) are silently skipped
        return decoded_bytes.decode('utf-8')

    # ── Analysis ──────────────────────────────────────────────────────

    def analyze(self, text: str) -> dict:
        """Analyze a string for emoji-cipher characteristics."""
        mapped_count = sum(1 for c in text if c in self._reverse)
        total_emoji = sum(1 for c in text if ord(c) > 0x1F000)
        unmapped = total_emoji - mapped_count

        return {
            'method': 'Emoji Substitution Cipher Analysis',
            'total_emoji_chars': total_emoji,
            'mapped_to_cipher': mapped_count,
            'unmapped_noise': unmapped,
            'estimated_payload_bytes': mapped_count,
            'likely_cipher': mapped_count > 4 and mapped_count / max(total_emoji, 1) > 0.5,
        }

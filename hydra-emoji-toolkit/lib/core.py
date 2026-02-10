"""
Hydra Emoji Smuggling Toolkit - Core Engine
============================================
Educational steganography library demonstrating how data can be
hidden within Unicode emoji sequences using multiple techniques.

FOR EDUCATIONAL AND AUTHORIZED SECURITY TESTING ONLY.

Techniques implemented:
  1. Zero-Width Character (ZWC) smuggling
  2. Variation Selector steganography
  3. Emoji substitution cipher
  4. Regional Indicator encoding

Each "head" of the hydra represents a different encoding channel,
demonstrating defense-in-depth concepts for security training.
"""

from __future__ import annotations

import sys
import os

# Unicode zero-width characters used for binary encoding
ZWC_ZERO = '\u200b'   # ZERO WIDTH SPACE        -> binary 0
ZWC_ONE  = '\u200c'   # ZERO WIDTH NON-JOINER   -> binary 1
ZWC_SEP  = '\u200d'   # ZERO WIDTH JOINER       -> byte separator
ZWC_MARK = '\ufeff'   # BYTE ORDER MARK         -> message boundary

# Variation selectors (VS1-VS16): invisible modifiers on preceding char
VARIATION_SELECTORS = [chr(c) for c in range(0xFE00, 0xFE10)]  # 16 selectors

# A pool of common emojis used as "carrier" cover text
CARRIER_EMOJIS = list(
    "\U0001F600\U0001F601\U0001F602\U0001F603\U0001F604\U0001F605"
    "\U0001F606\U0001F607\U0001F608\U0001F609\U0001F60A\U0001F60B"
    "\U0001F60C\U0001F60D\U0001F60E\U0001F60F\U0001F610\U0001F611"
    "\U0001F612\U0001F613\U0001F614\U0001F615\U0001F616\U0001F617"
    "\U0001F618\U0001F619\U0001F61A\U0001F61B\U0001F61C\U0001F61D"
    "\U0001F61E\U0001F61F"
)

# Regional indicator symbols A-Z (U+1F1E6 - U+1F1FF)
REGIONAL_INDICATORS = [chr(c) for c in range(0x1F1E6, 0x1F200)]


def text_to_bits(text: str) -> list[str]:
    """Convert UTF-8 text to a list of 8-bit binary strings."""
    return [format(b, '08b') for b in text.encode('utf-8')]


def bits_to_text(bits: list[str]) -> str:
    """Convert a list of 8-bit binary strings back to UTF-8 text."""
    return bytes(int(b, 2) for b in bits).decode('utf-8')

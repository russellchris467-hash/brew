"""
Multi-Layer Encoding Chainer
=============================
Stacks multiple steganography methods for layered encoding.
Useful during pentesting to bypass filters that only check for
one type of steganography at a time.

FOR AUTHORIZED SECURITY TESTING ONLY.
"""

from __future__ import annotations

import json

from .zwc_smuggler import ZWCSmuggler
from .variation_steg import VariationSteg
from .emoji_cipher import EmojiCipher
from .regional_encoder import RegionalEncoder


# Registry of available methods
METHODS = {
    'zwc': {
        'name': 'Zero-Width Character',
        'encode': lambda msg, **kw: ZWCSmuggler.encode(msg, cover_emojis=kw.get('cover')),
        'decode': lambda msg, **kw: ZWCSmuggler.decode(msg),
    },
    'vs': {
        'name': 'Variation Selector',
        'encode': lambda msg, **kw: VariationSteg.encode(msg, cover_emojis=kw.get('cover')),
        'decode': lambda msg, **kw: VariationSteg.decode(msg),
    },
    'cipher': {
        'name': 'Emoji Cipher',
        'encode': lambda msg, **kw: EmojiCipher(key=kw.get('key', 42)).encode(
            msg, noise_ratio=kw.get('noise', 0.0)
        ),
        'decode': lambda msg, **kw: EmojiCipher(key=kw.get('key', 42)).decode(msg),
    },
    'regional': {
        'name': 'Regional Indicator',
        'encode': lambda msg, **kw: RegionalEncoder.encode(msg),
        'decode': lambda msg, **kw: RegionalEncoder.decode(msg),
    },
}


def chain_encode(secret: str, methods: list[str], **kwargs) -> dict:
    """
    Encode a secret through multiple methods in sequence.

    Parameters
    ----------
    secret : str
        The plaintext to encode.
    methods : list[str]
        List of method names to apply in order (e.g., ['cipher', 'zwc']).
    **kwargs
        Passed to each method (key, cover, noise).

    Returns
    -------
    dict
        Result with encoded output, chain info, and intermediate sizes.
    """
    current = secret
    steps = []

    for method_name in methods:
        if method_name not in METHODS:
            raise ValueError(f"Unknown method: {method_name}. Available: {', '.join(METHODS)}")
        before_len = len(current)
        current = METHODS[method_name]['encode'](current, **kwargs)
        steps.append({
            'method': method_name,
            'input_len': before_len,
            'output_len': len(current),
            'expansion': f"{len(current) / max(before_len, 1):.1f}x",
        })

    return {
        'encoded': current,
        'chain': ' -> '.join(methods),
        'steps': steps,
        'total_expansion': f"{len(current) / max(len(secret), 1):.1f}x",
    }


def chain_decode(encoded: str, methods: list[str], **kwargs) -> dict:
    """
    Decode through multiple methods in reverse order.

    Parameters
    ----------
    encoded : str
        The encoded payload.
    methods : list[str]
        The encoding chain (will be reversed for decoding).
    **kwargs
        Passed to each method (key, etc.).

    Returns
    -------
    dict
        Result with decoded output and chain info.
    """
    current = encoded
    reversed_methods = list(reversed(methods))
    steps = []

    for method_name in reversed_methods:
        if method_name not in METHODS:
            raise ValueError(f"Unknown method: {method_name}")
        before_len = len(current)
        current = METHODS[method_name]['decode'](current, **kwargs)
        steps.append({
            'method': method_name,
            'input_len': before_len,
            'output_len': len(current),
        })

    return {
        'decoded': current,
        'chain': ' -> '.join(reversed_methods),
        'steps': steps,
    }

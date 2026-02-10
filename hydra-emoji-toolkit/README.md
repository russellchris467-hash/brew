# Hydra Emoji Smuggling Toolkit

**Educational steganography toolkit demonstrating how data can be covertly
encoded within Unicode emoji sequences.**

> FOR EDUCATIONAL AND AUTHORIZED SECURITY TESTING ONLY.
> This toolkit is intended for white-hat security training, CTF challenges,
> and understanding steganographic techniques for defensive purposes.

## Overview

The Hydra toolkit implements four distinct emoji-based data smuggling
techniques ("heads"), plus a defensive detector module. Each method exploits
different properties of Unicode to hide arbitrary data within emoji text that
appears innocuous to casual observers.

```
  _   _           _
 | | | |_   _  __| |_ __ __ _
 | |_| | | | |/ _` | '__/ _` |
 |  _  | |_| | (_| | | | (_| |
 |_| |_|\__, |\__,_|_|  \__,_|
        |___/
```

## The Four Heads

### Head 1: Zero-Width Character Smuggling (`zwc`)

**Technique:** Inserts invisible Unicode zero-width characters between visible
emojis. Each bit of the secret is mapped to either U+200B (ZERO WIDTH SPACE)
for `0` or U+200C (ZERO WIDTH NON-JOINER) for `1`. Bytes are separated by
U+200D (ZERO WIDTH JOINER), and the payload is bookended by U+FEFF (BOM)
boundary markers.

**Detection difficulty:** LOW - any zero-width character scanner will find it.

**Defensive takeaway:** Always scan incoming text for unexpected zero-width
characters. A high invisible-to-visible character ratio is a red flag.

```bash
python3 bin/hydra encode zwc "secret message"
python3 bin/hydra decode zwc "<encoded_string>"
```

### Head 2: Variation Selector Steganography (`vs`)

**Technique:** Appends Unicode Variation Selectors (VS1-VS16, U+FE00-U+FE0F)
after carrier emojis. Since there are 16 selectors, each encodes a 4-bit
nibble (0-15). Two emojis encode one byte. The variation selectors are
invisible in most renderers.

**Detection difficulty:** MEDIUM - variation selectors are legitimate Unicode
but unusual on emojis that don't have registered glyph variants.

**Defensive takeaway:** Monitor for unexpected variation selector usage,
especially on emojis that don't have standardized text/emoji presentation
variants.

```bash
python3 bin/hydra encode vs "secret message"
python3 bin/hydra decode vs "<encoded_string>"
```

### Head 3: Emoji Substitution Cipher (`cipher`)

**Technique:** Maps each byte value (0-255) to a unique emoji using a
PRNG-seeded shuffle. The secret becomes a string of emojis that looks
random but encodes a byte stream. Optionally adds "noise" emojis from
outside the mapping to increase confusion.

**Detection difficulty:** HIGH without the key. Statistical analysis can
reveal non-random distribution patterns compared to organic emoji usage.

**Defensive takeaway:** Watch for emoji strings with unusually high diversity
ratios or emoji characters from uncommon Unicode blocks.

```bash
python3 bin/hydra encode cipher "secret message" --key 42
python3 bin/hydra decode cipher "<encoded_string>" --key 42
python3 bin/hydra encode cipher "noisy" --key 42 --noise 0.3
```

### Head 4: Regional Indicator Encoding (`regional`)

**Technique:** Encodes data as a base-26 number using Regional Indicator
Symbols (U+1F1E6-U+1F1FF). Pairs of these symbols render as country flag
emojis, so the output looks like a string of flags. A 2-symbol length
prefix enables correct decoding.

**Detection difficulty:** MEDIUM - many flags may look odd but are plausible
in international contexts. Non-geographic patterns reveal the encoding.

**Defensive takeaway:** Flag sequences that don't correspond to real countries
or show non-geographic frequency distributions may contain encoded data.

```bash
python3 bin/hydra encode regional "secret message"
python3 bin/hydra decode regional "<encoded_string>"
```

## Defensive Tools

### Scanner

The `scan` command runs all detection methods against a suspect string:

```bash
python3 bin/hydra scan "<suspect_text>" --verbose
```

Output includes threat level (CLEAN/LOW/MEDIUM/HIGH), methods detected,
invisible character ratios, and per-method breakdowns.

### Hex Dump

```bash
python3 bin/hydra hexdump "<suspect_text>"
```

Shows raw hex bytes to reveal hidden characters invisible in terminals.

### Codepoint Dump

```bash
python3 bin/hydra codepoints "<suspect_text>"
```

Lists every character with its Unicode codepoint, name, and VISIBLE/INVISIBLE
classification. This is the single most effective way to spot steganography.

## Running the Demo

```bash
python3 bin/hydra demo
```

Encodes "Hello, Hydra!" with all four methods, verifies roundtrip decoding,
then runs the detector against the ZWC-encoded output.

## Running Tests

```bash
python3 test/test_hydra.py
```

29 tests covering all four encoding methods, error handling, and detector
accuracy.

## Project Structure

```
hydra-emoji-toolkit/
  bin/hydra              # CLI entry point
  lib/
    __init__.py          # Package exports
    core.py              # Shared constants and utilities
    zwc_smuggler.py      # Head 1: Zero-Width Character smuggling
    variation_steg.py    # Head 2: Variation Selector steganography
    emoji_cipher.py      # Head 3: Emoji substitution cipher
    regional_encoder.py  # Head 4: Regional Indicator encoding
    detector.py          # Defensive scanner / analysis module
  test/
    test_hydra.py        # Unit tests for all methods
```

## Unicode Concepts Used

| Concept | Codepoints | Visibility |
|---------|-----------|------------|
| Zero-Width Space | U+200B | Invisible |
| Zero-Width Non-Joiner | U+200C | Invisible |
| Zero-Width Joiner | U+200D | Invisible |
| Byte Order Mark | U+FEFF | Invisible |
| Variation Selectors 1-16 | U+FE00-U+FE0F | Invisible |
| Regional Indicators A-Z | U+1F1E6-U+1F1FF | Render as flags |
| Emoticons | U+1F600-U+1F64F | Visible emoji |

## Security Training Applications

- **Red team exercises:** Demonstrate data exfiltration via chat/messaging
- **Blue team training:** Practice detecting covert channels in text
- **CTF challenges:** Build puzzles around multi-layer emoji encoding
- **Awareness training:** Show non-technical staff that emojis can carry hidden data
- **Policy development:** Inform DLP (Data Loss Prevention) rule creation

#!/usr/bin/env python3
"""
emoji_steg.py - Emoji steganography toolkit for CTF challenges.

Supports multiple Unicode steganography methods:
  1. Variation Selectors (VS1-VS16, U+FE00-U+FE0F)
  2. Zero-Width Characters (ZWSP, ZWNJ, ZWJ, WJ)
  3. Unicode Tag Sequences (U+E0001-U+E007F)

Usage:
  python3 emoji_steg.py encode -m vs    -t "secret" [-c "🍺🏠☕"]
  python3 emoji_steg.py decode -m vs    -t "🍺︆︂..."
  python3 emoji_steg.py detect          -t "suspicious text"
  python3 emoji_steg.py encode -m zw    -t "secret" [-c "🍺🏠☕"]
  python3 emoji_steg.py decode -m zw    -t "🍺​‌..."
  python3 emoji_steg.py encode -m tag   -t "secret" [-c "🏴"]
  python3 emoji_steg.py decode -m tag   -t "🏴\U000e0068..."
"""

import argparse
import re
import sys


# ---------------------------------------------------------------------------
# Method 1: Variation Selectors (VS1-VS16)
# Each byte -> two nibbles -> two variation selectors (U+FE00 - U+FE0F)
# ---------------------------------------------------------------------------

VS_BASE = 0xFE00

def vs_encode(secret: str, carrier: str) -> str:
    payload = ""
    for byte in secret.encode("utf-8"):
        high = (byte >> 4) & 0x0F
        low = byte & 0x0F
        payload += chr(VS_BASE + high) + chr(VS_BASE + low)

    graphemes = list(carrier)
    if not graphemes:
        raise ValueError("Carrier must contain at least one character")
    return graphemes[0] + payload + "".join(graphemes[1:])


def vs_decode(text: str) -> str:
    nibbles = [ord(ch) - VS_BASE for ch in text if VS_BASE <= ord(ch) <= VS_BASE + 15]
    if not nibbles:
        raise ValueError("No variation-selector data found")
    if len(nibbles) % 2 != 0:
        raise ValueError(f"Corrupt data: odd nibble count ({len(nibbles)})")

    out = bytes((nibbles[i] << 4) | nibbles[i + 1] for i in range(0, len(nibbles), 2))
    return out.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Method 2: Zero-Width Characters
# Each bit -> ZWSP (0) or ZWNJ (1), with ZWJ as byte separator
# ---------------------------------------------------------------------------

ZWSP = "\u200B"   # zero-width space       -> 0
ZWNJ = "\u200C"   # zero-width non-joiner  -> 1
ZWJ  = "\u200D"   # zero-width joiner      -> byte separator
WJ   = "\u2060"   # word joiner            -> message boundary

ZW_CHARS = {ZWSP, ZWNJ, ZWJ, WJ}


def zw_encode(secret: str, carrier: str) -> str:
    parts = []
    for byte in secret.encode("utf-8"):
        bits = ""
        for i in range(7, -1, -1):
            bits += ZWSP if (byte >> i) & 1 == 0 else ZWNJ
        parts.append(bits)

    payload = WJ + ZWJ.join(parts) + WJ

    graphemes = list(carrier)
    if not graphemes:
        raise ValueError("Carrier must contain at least one character")
    return graphemes[0] + payload + "".join(graphemes[1:])


def zw_decode(text: str) -> str:
    # Extract everything between WJ boundaries
    start = text.find(WJ)
    if start == -1:
        raise ValueError("No zero-width message boundary found")
    end = text.find(WJ, start + 1)
    if end == -1:
        raise ValueError("No closing message boundary found")

    payload = text[start + 1:end]
    byte_strs = payload.split(ZWJ)

    out = bytearray()
    for bs in byte_strs:
        if not bs:
            continue
        val = 0
        for ch in bs:
            val <<= 1
            if ch == ZWNJ:
                val |= 1
            elif ch == ZWSP:
                pass
            else:
                continue
        out.append(val & 0xFF)

    return out.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Method 3: Unicode Tag Sequences (U+E0000 block)
# Each ASCII byte (0x00-0x7F) maps to U+E0000 + byte
# Non-ASCII bytes are encoded as two-char hex via tag digits
# ---------------------------------------------------------------------------

TAG_BASE = 0xE0000
TAG_CANCEL = 0xE007F


def tag_encode(secret: str, carrier: str) -> str:
    payload = ""
    for byte in secret.encode("utf-8"):
        if byte <= 0x7F:
            payload += chr(TAG_BASE + byte)
        else:
            # Encode as: TAG_CANCEL + two hex-digit tag chars
            high = (byte >> 4) & 0x0F
            low = byte & 0x0F
            payload += chr(TAG_CANCEL)
            payload += chr(TAG_BASE + ord("0") + high) if high < 10 else chr(TAG_BASE + ord("a") + high - 10)
            payload += chr(TAG_BASE + ord("0") + low) if low < 10 else chr(TAG_BASE + ord("a") + low - 10)

    graphemes = list(carrier)
    if not graphemes:
        raise ValueError("Carrier must contain at least one character")
    return graphemes[0] + payload + "".join(graphemes[1:])


def tag_decode(text: str) -> str:
    tags = [ord(ch) - TAG_BASE for ch in text if TAG_BASE < ord(ch) <= TAG_CANCEL]
    if not tags:
        raise ValueError("No tag-sequence data found")

    out = bytearray()
    i = 0
    while i < len(tags):
        val = tags[i]
        if val == (TAG_CANCEL - TAG_BASE):
            # Next two tag chars encode a hex byte
            if i + 2 >= len(tags):
                break
            h = tags[i + 1] - ord("0") if tags[i + 1] >= ord("0") and tags[i + 1] <= ord("9") \
                else tags[i + 1] - ord("a") + 10
            l = tags[i + 2] - ord("0") if tags[i + 2] >= ord("0") and tags[i + 2] <= ord("9") \
                else tags[i + 2] - ord("a") + 10
            out.append((h << 4) | l)
            i += 3
        else:
            out.append(val & 0xFF)
            i += 1

    return out.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Detection: scan text for any hidden steganographic content
# ---------------------------------------------------------------------------

def detect(text: str) -> dict:
    results = {}

    # Check variation selectors
    vs_count = sum(1 for ch in text if VS_BASE <= ord(ch) <= VS_BASE + 15)
    if vs_count:
        results["variation_selectors"] = {
            "count": vs_count,
            "estimated_bytes": vs_count // 2,
        }
        try:
            results["variation_selectors"]["decoded"] = vs_decode(text)
        except Exception as e:
            results["variation_selectors"]["error"] = str(e)

    # Check zero-width characters
    zw_count = sum(1 for ch in text if ch in ZW_CHARS)
    if zw_count:
        results["zero_width"] = {
            "count": zw_count,
            "chars": {
                "ZWSP": sum(1 for ch in text if ch == ZWSP),
                "ZWNJ": sum(1 for ch in text if ch == ZWNJ),
                "ZWJ": sum(1 for ch in text if ch == ZWJ),
                "WJ": sum(1 for ch in text if ch == WJ),
            },
        }
        try:
            results["zero_width"]["decoded"] = zw_decode(text)
        except Exception as e:
            results["zero_width"]["error"] = str(e)

    # Check tag sequences
    tag_count = sum(1 for ch in text if TAG_BASE < ord(ch) <= TAG_CANCEL)
    if tag_count:
        results["tag_sequences"] = {
            "count": tag_count,
        }
        try:
            results["tag_sequences"]["decoded"] = tag_decode(text)
        except Exception as e:
            results["tag_sequences"]["error"] = str(e)

    return results


# ---------------------------------------------------------------------------
# Analysis: entropy, capacity metrics, and statistical detectability
# ---------------------------------------------------------------------------

import math
from collections import Counter


def shannon_entropy(data: bytes) -> float:
    """Calculate Shannon entropy (bits per byte) of raw bytes."""
    if not data:
        return 0.0
    freq = Counter(data)
    length = len(data)
    return -sum((c / length) * math.log2(c / length) for c in freq.values())


def unicode_category_histogram(text: str) -> dict:
    """Categorize each codepoint into broad Unicode ranges."""
    categories = {
        "ascii_printable": 0,
        "ascii_control": 0,
        "variation_selectors": 0,
        "zero_width": 0,
        "tag_characters": 0,
        "emoji": 0,
        "other_unicode": 0,
    }
    for ch in text:
        cp = ord(ch)
        if VS_BASE <= cp <= VS_BASE + 15:
            categories["variation_selectors"] += 1
        elif ch in ZW_CHARS:
            categories["zero_width"] += 1
        elif TAG_BASE < cp <= TAG_CANCEL:
            categories["tag_characters"] += 1
        elif 0x1F300 <= cp <= 0x1FAFF or 0x2600 <= cp <= 0x27BF:
            categories["emoji"] += 1
        elif 32 <= cp <= 126:
            categories["ascii_printable"] += 1
        elif cp < 32 or cp == 127:
            categories["ascii_control"] += 1
        else:
            categories["other_unicode"] += 1
    return categories


def analyze(text: str) -> dict:
    """Full analysis of a steganographic text: entropy, histogram, capacity."""
    raw_bytes = text.encode("utf-8")
    histogram = unicode_category_histogram(text)
    total_chars = len(text)
    visible_chars = total_chars - (
        histogram["variation_selectors"]
        + histogram["zero_width"]
        + histogram["tag_characters"]
    )
    hidden_chars = total_chars - visible_chars
    hidden_ratio = hidden_chars / total_chars if total_chars else 0.0

    return {
        "total_codepoints": total_chars,
        "total_utf8_bytes": len(raw_bytes),
        "visible_codepoints": visible_chars,
        "hidden_codepoints": hidden_chars,
        "hidden_ratio": round(hidden_ratio, 4),
        "entropy_bits_per_byte": round(shannon_entropy(raw_bytes), 4),
        "max_entropy": 8.0,
        "histogram": histogram,
    }


# ---------------------------------------------------------------------------
# Benchmark: compare all three methods on capacity, overhead, detectability
# ---------------------------------------------------------------------------

def benchmark(secret: str, carrier: str) -> dict:
    """Encode the same secret with all methods and compare metrics."""
    results = {}
    secret_bytes = len(secret.encode("utf-8"))

    for name, (enc_fn, dec_fn, desc) in METHODS.items():
        encoded = enc_fn(secret, carrier)
        decoded = dec_fn(encoded)
        correct = decoded == secret

        encoded_bytes = len(encoded.encode("utf-8"))
        carrier_bytes = len(carrier.encode("utf-8"))
        overhead_bytes = encoded_bytes - carrier_bytes
        analysis = analyze(encoded)

        results[name] = {
            "description": desc,
            "roundtrip_ok": correct,
            "secret_bytes": secret_bytes,
            "carrier_utf8_bytes": carrier_bytes,
            "encoded_utf8_bytes": encoded_bytes,
            "overhead_bytes": overhead_bytes,
            "overhead_ratio": round(overhead_bytes / carrier_bytes, 2) if carrier_bytes else 0,
            "bytes_per_secret_byte": round(overhead_bytes / secret_bytes, 2) if secret_bytes else 0,
            "hidden_codepoints": analysis["hidden_codepoints"],
            "hidden_ratio": analysis["hidden_ratio"],
            "entropy": analysis["entropy_bits_per_byte"],
        }

    return results


# ---------------------------------------------------------------------------
# Sanitize: defensive countermeasures to strip steganographic content
# ---------------------------------------------------------------------------

# All Unicode ranges used for steganographic hiding
STEG_RANGES = [
    (0xFE00, 0xFE0F),     # Variation Selectors
    (0xFE20, 0xFE2F),     # Combining Half Marks (sometimes abused)
    (0x200B, 0x200F),     # Zero-width and directional chars
    (0x2028, 0x202F),     # Line/paragraph separators, embedding controls
    (0x2060, 0x2064),     # Word joiner, invisible operators
    (0x2066, 0x206F),     # Bidi isolates and overrides
    (0xE0001, 0xE007F),   # Tag characters
    (0xE0100, 0xE01EF),   # Variation Selectors Supplement
    (0xFFF0, 0xFFFF),     # Specials (interlinear annotation, replacement)
]


def is_steg_char(cp: int) -> bool:
    """Check if a codepoint falls within known steganographic ranges."""
    return any(lo <= cp <= hi for lo, hi in STEG_RANGES)


def sanitize(text: str, report: bool = False) -> dict:
    """Strip all known steganographic/invisible Unicode from text.

    Returns a dict with 'clean' text and optionally a 'removed' report.
    """
    clean = []
    removed = []
    for i, ch in enumerate(text):
        cp = ord(ch)
        if is_steg_char(cp):
            removed.append({
                "index": i,
                "codepoint": f"U+{cp:04X}",
                "name": _cp_name(cp),
            })
        else:
            clean.append(ch)

    result = {"clean": "".join(clean), "removed_count": len(removed)}
    if report:
        result["removed"] = removed
    return result


def _cp_name(cp: int) -> str:
    """Best-effort name for a codepoint."""
    if VS_BASE <= cp <= VS_BASE + 15:
        return f"VS{cp - VS_BASE + 1}"
    if cp == 0x200B:
        return "ZWSP"
    if cp == 0x200C:
        return "ZWNJ"
    if cp == 0x200D:
        return "ZWJ"
    if cp == 0x2060:
        return "WJ"
    if 0xE0001 <= cp <= 0xE007F:
        mapped = cp - 0xE0000
        if 0x20 <= mapped <= 0x7E:
            return f"TAG '{chr(mapped)}'"
        return f"TAG 0x{mapped:02X}"
    if 0xE0100 <= cp <= 0xE01EF:
        return f"VS{cp - 0xE0100 + 17}"
    return f"U+{cp:04X}"


# ---------------------------------------------------------------------------
# Hydra output parser
# Parses credential lines from Hydra stdout and encodes each into emoji.
#
# Hydra success lines look like:
#   [22][ssh] host: 192.168.1.10   login: admin   password: secret123
#   [80][http-get] host: 10.0.0.1   login: root   password: toor
# ---------------------------------------------------------------------------

# Matches Hydra credential lines:  [port][service] host: H  login: L  password: P
HYDRA_CRED_RE = re.compile(
    r"\[(\d+)\]\[([^\]]+)\]\s+"
    r"host:\s*(\S+)\s+"
    r"login:\s*(\S+)\s+"
    r"password:\s*(\S*)",
)

# Service -> emoji mapping for carrier variety
SERVICE_EMOJI = {
    "ssh":       "\U0001F5A5\U0001F510",   # desktop + lock
    "ftp":       "\U0001F4C2\U0001F511",   # folder + key
    "http-get":  "\U0001F310\U0001F513",   # globe + unlocked
    "http-post": "\U0001F310\U0001F4E8",   # globe + envelope
    "rdp":       "\U0001F5A5\U0001F6AA",   # desktop + door
    "smb":       "\U0001F4C1\U0001F50F",   # folder + lock-pen
    "mysql":     "\U0001F4BE\U0001F511",   # floppy + key
    "postgres":  "\U0001F418\U0001F511",   # elephant + key
    "vnc":       "\U0001F4F1\U0001F50D",   # phone + magnifier
    "telnet":    "\U0001F4DF\U0001F513",   # pager + unlocked
    "smtp":      "\U0001F4E7\U0001F511",   # email + key
    "pop3":      "\U0001F4EC\U0001F511",   # mailbox + key
    "imap":      "\U0001F4E5\U0001F511",   # inbox + key
}

DEFAULT_SERVICE_EMOJI = "\U0001F510\U0001F511"  # lock + key


def parse_hydra_output(text: str) -> list:
    """Extract credentials from Hydra output text.

    Returns a list of dicts with keys: port, service, host, login, password.
    """
    creds = []
    for line in text.splitlines():
        m = HYDRA_CRED_RE.search(line)
        if m:
            creds.append({
                "port":     m.group(1),
                "service":  m.group(2),
                "host":     m.group(3),
                "login":    m.group(4),
                "password": m.group(5),
            })
    return creds


def hydra_encode(text: str, method: str, carrier: str | None) -> list:
    """Parse Hydra output and encode each credential as an emoji-steg string.

    Returns a list of (summary, encoded_string) tuples.
    """
    creds = parse_hydra_output(text)
    if not creds:
        raise ValueError("No Hydra credentials found in input. "
                         "Expected lines like: [22][ssh] host: x  login: y  password: z")

    encode_fn = METHODS[method][0]
    results = []

    for cred in creds:
        secret = f"{cred['host']}:{cred['port']} {cred['login']}:{cred['password']}"
        if carrier:
            emoji_carrier = carrier
        else:
            emoji_carrier = SERVICE_EMOJI.get(cred["service"], DEFAULT_SERVICE_EMOJI)
        encoded = encode_fn(secret, emoji_carrier)
        summary = f"[{cred['service']}] {cred['host']}:{cred['port']}"
        results.append((summary, encoded))

    return results


def hydra_decode(text: str, method: str) -> list:
    """Decode emoji-steg strings (one per line) back to credential format."""
    decode_fn = METHODS[method][1]
    results = []
    for line in text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            decoded = decode_fn(line)
            results.append(decoded)
        except ValueError:
            continue
    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

DEFAULT_CARRIER = "\U0001F37A\U0001F3E0\u2615\U0001F4E6\U0001F680"

METHODS = {
    "vs": (vs_encode, vs_decode, "Variation Selectors (U+FE00-U+FE0F)"),
    "zw": (zw_encode, zw_decode, "Zero-Width Characters"),
    "tag": (tag_encode, tag_decode, "Unicode Tag Sequences (U+E0000)"),
}


def main():
    parser = argparse.ArgumentParser(
        description="Emoji steganography toolkit for CTF challenges",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
methods:
  vs    Variation selectors - 4 bits per selector, 2 selectors per byte
  zw    Zero-width chars    - 8 bits per byte + separators
  tag   Tag sequences       - 1 tag char per ASCII byte

actions:
  encode        Encode a secret into an emoji carrier
  decode        Decode a hidden message from steg text
  detect        Scan text for hidden steganographic content
  analyze       Entropy, histogram, and capacity metrics
  benchmark     Compare all methods on the same secret
  sanitize      Strip all hidden Unicode (defensive)
  hydra         Parse Hydra output and encode credentials
  hydra-decode  Decode emoji-encoded credentials

examples:
  %(prog)s encode    -m vs  -t "flag{hidden}"
  %(prog)s decode    -m vs  -t "<encoded string>"
  %(prog)s detect           -t "<suspicious string>"
  %(prog)s analyze          -t "<steg string>"
  %(prog)s benchmark -m vs  -t "test payload"
  %(prog)s sanitize         -t "<dirty string>"
  %(prog)s hydra     -m vs  --stdin < hydra_output.txt
  %(prog)s hydra-decode -m vs --stdin < encoded_creds.txt
        """,
    )

    parser.add_argument("action", choices=[
                            "encode", "decode", "detect", "analyze",
                            "benchmark", "sanitize", "hydra", "hydra-decode",
                        ],
                        help="Action to perform")
    parser.add_argument("-m", "--method", choices=list(METHODS.keys()), default="vs",
                        help="Steganography method (default: vs)")
    parser.add_argument("-t", "--text", help="Input text (secret for encode, steg-text for decode)")
    parser.add_argument("-c", "--carrier", default=DEFAULT_CARRIER,
                        help="Carrier emoji string for encoding")
    parser.add_argument("--stdin", action="store_true",
                        help="Read input from stdin instead of -t")

    args = parser.parse_args()

    if args.stdin:
        text = sys.stdin.read()
    elif args.text:
        text = args.text
    else:
        parser.error("Provide input with -t or --stdin")
        return

    if args.action == "detect":
        results = detect(text)
        if not results:
            print("No hidden steganographic content detected.")
            return

        print("Hidden content detected:\n")
        for method, info in results.items():
            print(f"  [{method}]")
            for k, v in info.items():
                if isinstance(v, dict):
                    print(f"    {k}:")
                    for kk, vv in v.items():
                        print(f"      {kk}: {vv}")
                else:
                    print(f"    {k}: {v}")
            print()
        return

    if args.action == "analyze":
        info = analyze(text)
        print("Steganographic Analysis")
        print("=" * 50)
        print(f"  Total codepoints:    {info['total_codepoints']}")
        print(f"  Total UTF-8 bytes:   {info['total_utf8_bytes']}")
        print(f"  Visible codepoints:  {info['visible_codepoints']}")
        print(f"  Hidden codepoints:   {info['hidden_codepoints']}")
        print(f"  Hidden ratio:        {info['hidden_ratio']:.1%}")
        print(f"  Shannon entropy:     {info['entropy_bits_per_byte']:.4f} bits/byte (max 8.0)")
        print()
        print("  Unicode Category Histogram:")
        for cat, count in info["histogram"].items():
            if count > 0:
                bar = "#" * min(count, 40)
                print(f"    {cat:25s} {count:5d}  {bar}")
        print()

        # Detectability assessment
        ratio = info["hidden_ratio"]
        if ratio == 0:
            verdict = "CLEAN - no hidden characters detected"
        elif ratio < 0.3:
            verdict = "LOW  - small amount of hidden content, may pass casual inspection"
        elif ratio < 0.6:
            verdict = "MED  - significant hidden content, detectable by Unicode scanners"
        else:
            verdict = "HIGH - mostly hidden content, easily flagged by any filter"
        print(f"  Detectability: {verdict}")
        return

    if args.action == "benchmark":
        carrier = args.carrier
        results = benchmark(text, carrier)
        print("Method Comparison Benchmark")
        print("=" * 70)
        print(f"  Secret:  {text!r} ({len(text.encode('utf-8'))} bytes)")
        print(f"  Carrier: {carrier} ({len(carrier.encode('utf-8'))} UTF-8 bytes)")
        print()

        # Table header
        print(f"  {'Method':<6} {'Overhead':>10} {'B/secret':>10} {'Hidden%':>10} {'Entropy':>10} {'OK':>4}")
        print(f"  {'-'*6} {'-'*10} {'-'*10} {'-'*10} {'-'*10} {'-'*4}")
        for name, info in results.items():
            print(f"  {name:<6} {info['overhead_bytes']:>8} B {info['bytes_per_secret_byte']:>8.1f}x"
                  f" {info['hidden_ratio']:>9.1%} {info['entropy']:>8.4f}  "
                  f"{'Y' if info['roundtrip_ok'] else 'N':>3}")
        print()

        # Recommendations
        smallest = min(results, key=lambda k: results[k]["overhead_bytes"])
        stealthiest = min(results, key=lambda k: results[k]["hidden_ratio"])
        print(f"  Smallest overhead: {smallest} ({results[smallest]['overhead_bytes']} bytes)")
        print(f"  Lowest hidden ratio: {stealthiest} ({results[stealthiest]['hidden_ratio']:.1%})")
        print()
        print("  Notes:")
        print("    - vs:  Compact, but VS chars cluster unnaturally after emojis")
        print("    - zw:  Bit-level encoding; higher overhead but uses common chars")
        print("    - tag: 1:1 for ASCII; tag block is rarely seen in normal text")
        return

    if args.action == "sanitize":
        result = sanitize(text, report=True)
        clean = result["clean"]
        removed_count = result["removed_count"]

        if removed_count == 0:
            print("Text is clean. No steganographic characters found.")
            print(f"\n{text}")
        else:
            print(f"Sanitized: removed {removed_count} hidden character(s)")
            print()
            print(f"  Clean text: {clean}")
            print()
            print("  Removed characters:")
            for entry in result["removed"]:
                print(f"    pos {entry['index']:4d}: {entry['codepoint']}  ({entry['name']})")
        return

    if args.action == "hydra":
        results = hydra_encode(text, args.method, args.carrier if args.carrier != DEFAULT_CARRIER else None)
        print(f"Encoded {len(results)} credential(s):\n")
        for summary, encoded in results:
            print(f"  {summary}")
            print(f"    {encoded}")
            print()
        # Also print just the encoded strings for piping
        print("--- raw (one per line, for piping to hydra-decode) ---")
        for _, encoded in results:
            print(encoded)
        return

    if args.action == "hydra-decode":
        results = hydra_decode(text, args.method)
        if not results:
            print("No encoded credentials found in input.")
            return
        print(f"Decoded {len(results)} credential(s):\n")
        for cred in results:
            parts = cred.split(" ", 1)
            if len(parts) == 2:
                host_port, login_pass = parts
                print(f"  host:port  = {host_port}")
                print(f"  login:pass = {login_pass}")
            else:
                print(f"  {cred}")
            print()
        return

    encode_fn, decode_fn, method_name = METHODS[args.method]

    if args.action == "encode":
        result = encode_fn(text, args.carrier)
        print(result)
    elif args.action == "decode":
        result = decode_fn(text)
        print(result)


if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    main()

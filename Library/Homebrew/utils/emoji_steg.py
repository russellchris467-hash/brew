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

examples:
  %(prog)s encode  -m vs  -t "flag{hidden}"
  %(prog)s encode  -m vs  -t "flag{hidden}" -c "🎉🎊🎈"
  %(prog)s decode  -m vs  -t "<encoded string>"
  %(prog)s detect         -t "<suspicious string>"
  %(prog)s hydra   -m vs  --stdin < hydra_output.txt
  %(prog)s hydra   -m vs  -t "[22][ssh] host: 10.0.0.1   login: admin   password: pass"
  %(prog)s hydra-decode -m vs --stdin < encoded_creds.txt
        """,
    )

    parser.add_argument("action", choices=["encode", "decode", "detect", "hydra", "hydra-decode"],
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

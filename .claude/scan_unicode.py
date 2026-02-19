#!/usr/bin/env python3
"""
SPECTER-256-style Unicode Scanner — Claude tool + standalone web app.

Modes
-----
  Web server (default):   python scan_unicode.py [--port 8080]
  CLI one-shot:           python scan_unicode.py --cli "some text here"

Endpoints (web mode)
--------------------
  GET  /           Browser UI
  POST /api/scan   JSON API  { "text": "..." } -> scan result dict

Claude tool integration
-----------------------
  TOOLS               — schema list to pass to the Claude API
  scan_unicode_tool() — implementation that Claude calls via tool_use
"""

import io
import json
import sys
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, Any


# ---------------------------------------------------------------------------
# 1) Claude tool schema
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "scan_unicode",
        "description": (
            "Defensive scanner that inspects text for hidden Unicode, "
            "non-ASCII, control characters, zero-width invisibles, and "
            "visual homoglyphs using a SPECTER-256-style analyzer."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": (
                        "The raw text to scan for hidden Unicode characters, "
                        "zero-width invisibles, homoglyphs, and suspicious "
                        "control characters."
                    ),
                }
            },
            "required": ["text"],
        },
    }
]


# ---------------------------------------------------------------------------
# 2) Detection tables
# ---------------------------------------------------------------------------

# Zero-width and invisible formatting characters that leave no visible trace.
_ZERO_WIDTH = {
    0x00AD: "SOFT HYPHEN",
    0x200B: "ZERO WIDTH SPACE",
    0x200C: "ZERO WIDTH NON-JOINER",
    0x200D: "ZERO WIDTH JOINER",
    0x200E: "LEFT-TO-RIGHT MARK",
    0x200F: "RIGHT-TO-LEFT MARK",
    0x2028: "LINE SEPARATOR",
    0x2029: "PARAGRAPH SEPARATOR",
    0x202A: "LEFT-TO-RIGHT EMBEDDING",
    0x202B: "RIGHT-TO-LEFT EMBEDDING",
    0x202C: "POP DIRECTIONAL FORMATTING",
    0x202D: "LEFT-TO-RIGHT OVERRIDE",
    0x202E: "RIGHT-TO-LEFT OVERRIDE",
    0x2060: "WORD JOINER",
    0x2061: "FUNCTION APPLICATION",
    0x2062: "INVISIBLE TIMES",
    0x2063: "INVISIBLE SEPARATOR",
    0x2064: "INVISIBLE PLUS",
    0xFEFF: "ZERO WIDTH NO-BREAK SPACE (BOM)",
}

# Common visual homoglyphs mapped to the ASCII character they impersonate.
# Covers Cyrillic, Greek, fullwidth Latin, and selected lookalikes.
_HOMOGLYPHS: Dict[int, str] = {
    # Cyrillic lookalikes
    0x0410: "A", 0x0430: "a",
    0x0412: "B",
    0x0421: "C", 0x0441: "c",
    0x0415: "E", 0x0435: "e",
    0x041D: "H",
    0x0406: "I", 0x0456: "i",
    0x0408: "J",
    0x041A: "K",
    0x039C: "M",  # Greek Mu used as M lookalike too
    0x041E: "O", 0x043E: "o",
    0x0420: "P", 0x0440: "p",
    0x0405: "S",
    0x0422: "T",
    0x0412: "B",
    0x0425: "X", 0x0445: "x",
    0x0443: "y",
    # Greek lookalikes
    0x0391: "A", 0x03B1: "a",
    0x0392: "B",
    0x03F2: "c",
    0x0395: "E", 0x03B5: "e",
    0x0397: "H",
    0x0399: "I", 0x03B9: "i",
    0x039A: "K",
    0x039C: "M",
    0x039D: "N",
    0x039F: "O", 0x03BF: "o",
    0x03A1: "P", 0x03C1: "p",
    0x03A4: "T",
    0x03A5: "Y", 0x03C5: "u",
    0x03A7: "X",
    0x03BD: "v",
    0x03C9: "w",
    # Fullwidth Latin (U+FF01–U+FF5E mirror ASCII 0x21–0x7E)
    **{0xFF01 + i: chr(0x21 + i) for i in range(94)},
    # Superscript / subscript digits
    0x2070: "0", 0x00B9: "1", 0x00B2: "2", 0x00B3: "3",
    0x2074: "4", 0x2075: "5", 0x2076: "6", 0x2077: "7",
    0x2078: "8", 0x2079: "9",
    # Other common lookalikes
    0x01A0: "O",  # Latin O with horn
    0x00D8: "O",  # Latin O with stroke
    0x00F8: "o",
    0x013F: "L",  # Latin L with middle dot
    0x0399: "I",
    0x2223: "|",  # DIVIDES (pipe lookalike)
    0x2018: "'", 0x2019: "'",   # curved quotes
    0x201C: '"', 0x201D: '"',
    0x02BC: "'",  # modifier apostrophe
    0x0060: "`",  # already ASCII but listed for completeness
    0x00B4: "'",  # ACUTE ACCENT
    0x02BB: "'",
}


# ---------------------------------------------------------------------------
# 3) Core scanner — used by the web server, CLI, and Claude tool handler
# ---------------------------------------------------------------------------

def scan_unicode_tool(args: Dict[str, Any]) -> Dict[str, Any]:
    """
    Scan *args["text"]* for non-ASCII, control, zero-width, and homoglyph chars.

    Returns a dict with:
      summary              – human-readable report string
      non_ascii_count      – int
      control_count        – int
      zero_width_count     – int
      homoglyph_count      – int
      non_ascii_details    – list of {char, codepoint, hex}
      control_details      – list of {char, codepoint, hex}
      zero_width_details   – list of {char, codepoint, hex, name}
      homoglyph_details    – list of {char, codepoint, hex, looks_like}
    """
    text = args.get("text", "")
    non_ascii    = [(c, ord(c)) for c in text if ord(c) > 127]
    controls     = [(c, ord(c)) for c in text if ord(c) < 32 and c not in "\r\n\t"]
    zero_widths  = [(c, ord(c)) for c in text if ord(c) in _ZERO_WIDTH]
    homoglyphs   = [(c, ord(c)) for c in text if ord(c) in _HOMOGLYPHS]

    buf = io.StringIO()
    buf.write(f"[SPECTER-256] Text length: {len(text)}\n")

    if non_ascii:
        buf.write("[SPECTER-256] Non-ASCII characters detected:\n")
        for c, code in non_ascii:
            buf.write(f"  U+{code:04X} ({repr(c)})\n")
    else:
        buf.write("[SPECTER-256] No non-ASCII characters detected.\n")

    if controls:
        buf.write("[SPECTER-256] Control characters detected:\n")
        for c, code in controls:
            buf.write(f"  U+{code:04X} ({repr(c)})\n")
    else:
        buf.write("[SPECTER-256] No suspicious control characters detected.\n")

    if zero_widths:
        buf.write("[SPECTER-256] Zero-width/invisible characters detected:\n")
        for c, code in zero_widths:
            buf.write(f"  U+{code:04X} {_ZERO_WIDTH[code]}\n")
    else:
        buf.write("[SPECTER-256] No zero-width characters detected.\n")

    if homoglyphs:
        buf.write("[SPECTER-256] Homoglyph characters detected:\n")
        for c, code in homoglyphs:
            buf.write(f"  U+{code:04X} ({repr(c)}) looks like '{_HOMOGLYPHS[code]}'\n")
    else:
        buf.write("[SPECTER-256] No homoglyph characters detected.\n")

    return {
        "summary": buf.getvalue(),
        "non_ascii_count":    len(non_ascii),
        "control_count":      len(controls),
        "zero_width_count":   len(zero_widths),
        "homoglyph_count":    len(homoglyphs),
        "non_ascii_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}"}
            for c, code in non_ascii
        ],
        "control_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}"}
            for c, code in controls
        ],
        "zero_width_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}",
             "name": _ZERO_WIDTH[code]}
            for c, code in zero_widths
        ],
        "homoglyph_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}",
             "looks_like": _HOMOGLYPHS[code]}
            for c, code in homoglyphs
        ],
    }


# ---------------------------------------------------------------------------
# 3) Embedded browser UI (served at GET /)
# ---------------------------------------------------------------------------

_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SPECTER-256 Unicode Scanner</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: system-ui, sans-serif;
    background: #0f0f13;
    color: #e2e2e8;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem 1rem;
  }
  header { text-align: center; margin-bottom: 2rem; }
  header h1 { font-size: 1.8rem; letter-spacing: .05em; color: #a78bfa; }
  header p  { color: #888; font-size: .9rem; margin-top: .4rem; }
  .card {
    background: #1a1a24;
    border: 1px solid #2e2e40;
    border-radius: 12px;
    padding: 1.5rem;
    width: 100%;
    max-width: 680px;
    margin-bottom: 1.5rem;
  }
  textarea {
    width: 100%;
    min-height: 120px;
    background: #12121a;
    color: #e2e2e8;
    border: 1px solid #3a3a50;
    border-radius: 8px;
    padding: .75rem;
    font-size: .95rem;
    font-family: 'Courier New', monospace;
    resize: vertical;
    outline: none;
  }
  textarea:focus { border-color: #7c3aed; }
  button {
    margin-top: 1rem;
    background: #7c3aed;
    color: #fff;
    border: none;
    border-radius: 8px;
    padding: .65rem 1.6rem;
    font-size: 1rem;
    cursor: pointer;
    transition: background .2s;
  }
  button:hover { background: #6d28d9; }
  button:disabled { background: #444; cursor: default; }
  #stats { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
  .stat {
    background: #12121a;
    border: 1px solid #2e2e40;
    border-radius: 8px;
    padding: .5rem 1rem;
    font-size: .85rem;
    color: #a78bfa;
  }
  .stat span { color: #e2e2e8; font-weight: 700; }
  pre {
    background: #12121a;
    border: 1px solid #2e2e40;
    border-radius: 8px;
    padding: 1rem;
    font-size: .85rem;
    white-space: pre-wrap;
    word-break: break-all;
    color: #6ee7b7;
    max-height: 340px;
    overflow-y: auto;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: .85rem;
    margin-top: .5rem;
  }
  th { color: #a78bfa; text-align: left; padding: .4rem .6rem; border-bottom: 1px solid #2e2e40; }
  td { padding: .4rem .6rem; border-bottom: 1px solid #1e1e2c; font-family: monospace; }
  tr:last-child td { border-bottom: none; }
  .hidden { display: none; }
  .tag-clean { color: #6ee7b7; }
  .tag-warn  { color: #fbbf24; }
</style>
</head>
<body>

<header>
  <h1>&#x1F50D; SPECTER-256 Unicode Scanner</h1>
  <p>Detects hidden Unicode, non-ASCII, and suspicious control characters</p>
</header>

<div class="card">
  <textarea id="input" placeholder="Paste text to scan…"></textarea>
  <button id="btn" onclick="scan()">Scan</button>
</div>

<div id="results" class="card hidden">
  <div id="stats"></div>
  <pre id="summary"></pre>

  <div id="zero-width-section">
    <h3 style="margin: 1rem 0 .5rem; color:#f87171;">Zero-width / invisible</h3>
    <table>
      <thead><tr><th>Hex</th><th>Codepoint</th><th>Name</th></tr></thead>
      <tbody id="zero-width-rows"></tbody>
    </table>
  </div>

  <div id="homoglyph-section">
    <h3 style="margin: 1rem 0 .5rem; color:#fb923c;">Homoglyphs</h3>
    <table>
      <thead><tr><th>Hex</th><th>Codepoint</th><th>repr</th><th>Looks like</th></tr></thead>
      <tbody id="homoglyph-rows"></tbody>
    </table>
  </div>

  <div id="non-ascii-section">
    <h3 style="margin: 1rem 0 .5rem; color:#a78bfa;">Non-ASCII characters</h3>
    <table>
      <thead><tr><th>Hex</th><th>Codepoint</th><th>repr</th></tr></thead>
      <tbody id="non-ascii-rows"></tbody>
    </table>
  </div>

  <div id="control-section">
    <h3 style="margin: 1rem 0 .5rem; color:#a78bfa;">Control characters</h3>
    <table>
      <thead><tr><th>Hex</th><th>Codepoint</th><th>repr</th></tr></thead>
      <tbody id="control-rows"></tbody>
    </table>
  </div>
</div>

<script>
async function scan() {
  const text = document.getElementById('input').value;
  const btn  = document.getElementById('btn');
  btn.disabled = true;
  btn.textContent = 'Scanning…';

  try {
    const res  = await fetch('/api/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text })
    });
    const data = await res.json();
    render(data);
  } catch (e) {
    alert('Error: ' + e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Scan';
  }
}

function row(d) {
  return `<tr><td>${d.hex}</td><td>${d.codepoint}</td><td>${escHtml(String(d.char))}</td></tr>`;
}

function zwRow(d) {
  return `<tr><td>${d.hex}</td><td>${d.codepoint}</td><td>${escHtml(d.name)}</td></tr>`;
}

function hgRow(d) {
  return `<tr><td>${d.hex}</td><td>${d.codepoint}</td><td>${escHtml(String(d.char))}</td><td>'${escHtml(d.looks_like)}'</td></tr>`;
}

function escHtml(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function toggle(sectionId, rowsId, details, renderFn) {
  const sec = document.getElementById(sectionId);
  if (!details || details.length === 0) {
    sec.classList.add('hidden');
  } else {
    sec.classList.remove('hidden');
    document.getElementById(rowsId).innerHTML = details.map(renderFn).join('');
  }
}

function render(data) {
  document.getElementById('results').classList.remove('hidden');

  const naOk = data.non_ascii_count   === 0;
  const ctOk = data.control_count     === 0;
  const zwOk = data.zero_width_count  === 0;
  const hgOk = data.homoglyph_count   === 0;
  const len  = parseInt(data.summary.split('\\n')[0].split(': ')[1]) || 0;

  document.getElementById('stats').innerHTML = `
    <div class="stat">Length <span>${len}</span></div>
    <div class="stat">Zero-width <span class="${zwOk?'tag-clean':'tag-warn'}">${data.zero_width_count}</span></div>
    <div class="stat">Homoglyphs <span class="${hgOk?'tag-clean':'tag-warn'}">${data.homoglyph_count}</span></div>
    <div class="stat">Non-ASCII <span class="${naOk?'tag-clean':'tag-warn'}">${data.non_ascii_count}</span></div>
    <div class="stat">Controls <span class="${ctOk?'tag-clean':'tag-warn'}">${data.control_count}</span></div>
  `;

  document.getElementById('summary').textContent = data.summary;

  toggle('zero-width-section', 'zero-width-rows', data.zero_width_details, zwRow);
  toggle('homoglyph-section',  'homoglyph-rows',  data.homoglyph_details,  hgRow);
  toggle('non-ascii-section',  'non-ascii-rows',  data.non_ascii_details,  row);
  toggle('control-section',    'control-rows',    data.control_details,    row);
}
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# 4) HTTP request handler
# ---------------------------------------------------------------------------

class _Handler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):  # suppress default access log noise
        print(f"  {self.address_string()} {fmt % args}")

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = _HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/api/scan":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", 0))
        raw    = self.rfile.read(length)

        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        result = scan_unicode_tool(payload)
        body   = json.dumps(result, ensure_ascii=False).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


# ---------------------------------------------------------------------------
# 5) MCP stdio server (for Claude Code integration)
# ---------------------------------------------------------------------------

_MCP_TOOLS = [
    {
        "name": "scan_unicode",
        "description": (
            "Defensive scanner that inspects text for hidden Unicode, "
            "non-ASCII, control characters, zero-width invisibles, and "
            "visual homoglyphs using a SPECTER-256-style analyzer."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": (
                        "The raw text to scan for hidden Unicode characters, "
                        "zero-width invisibles, homoglyphs, and suspicious "
                        "control characters."
                    ),
                }
            },
            "required": ["text"],
        },
    }
]


def _mcp_server():
    """
    MCP JSON-RPC 2.0 stdio server.
    Claude Code spawns this process and communicates over stdin/stdout.
    """
    import sys

    def send(obj):
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()

    def respond(id_, result):
        send({"jsonrpc": "2.0", "id": id_, "result": result})

    def error(id_, code, message):
        send({"jsonrpc": "2.0", "id": id_, "error": {"code": code, "message": message}})

    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue

        method = msg.get("method", "")
        id_    = msg.get("id")      # None for notifications

        if method == "initialize":
            respond(id_, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "scan_unicode", "version": "1.0.0"},
            })

        elif method == "notifications/initialized":
            pass  # no response for notifications

        elif method == "tools/list":
            respond(id_, {"tools": _MCP_TOOLS})

        elif method == "tools/call":
            params = msg.get("params", {})
            name   = params.get("name")
            args   = params.get("arguments", {})
            if name == "scan_unicode":
                result = scan_unicode_tool(args)
                respond(id_, {
                    "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}]
                })
            else:
                error(id_, -32601, f"Unknown tool: {name}")

        elif id_ is not None:
            error(id_, -32601, f"Method not found: {method}")


# ---------------------------------------------------------------------------
# 6) Entry points
# ---------------------------------------------------------------------------

def _serve(port: int):
    server = HTTPServer(("0.0.0.0", port), _Handler)
    print(f"SPECTER-256 Unicode Scanner listening on http://0.0.0.0:{port}")
    print(f"  Browser UI : http://localhost:{port}")
    print(f"  JSON API   : POST http://localhost:{port}/api/scan")
    print("Press Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


def _cli(text: str):
    result = scan_unicode_tool({"text": text})
    print(result["summary"])


def main():
    parser = argparse.ArgumentParser(
        description="SPECTER-256-style Unicode scanner — web app, CLI, or MCP server."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--serve", nargs="?", const=8080, type=int, metavar="PORT",
        help="Launch HTTP server (default port 8080)."
    )
    mode.add_argument(
        "--cli", metavar="TEXT",
        help="Scan TEXT and print results to stdout (no server)."
    )
    mode.add_argument(
        "--mcp", action="store_true",
        help="Run as MCP stdio server (used by Claude Code)."
    )
    args = parser.parse_args()

    if args.mcp:
        _mcp_server()
    elif args.cli is not None:
        _cli(args.cli)
    else:
        # Default: web server
        port = args.serve if args.serve is not None else 8080
        _serve(port)


if __name__ == "__main__":
    main()

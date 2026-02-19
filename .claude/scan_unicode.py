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
            "non-ASCII, and control characters using a SPECTER-256-style analyzer."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": (
                        "The raw text to scan for hidden Unicode characters "
                        "and suspicious control characters."
                    ),
                }
            },
            "required": ["text"],
        },
    }
]


# ---------------------------------------------------------------------------
# 2) Core scanner — used by the web server, CLI, and Claude tool handler
# ---------------------------------------------------------------------------

def scan_unicode_tool(args: Dict[str, Any]) -> Dict[str, Any]:
    """
    Scan *args["text"]* for non-ASCII and suspicious control characters.

    Returns a dict with:
      summary          – human-readable report string
      non_ascii_count  – int
      control_count    – int
      non_ascii_details – list of {char, codepoint, hex}
      control_details   – list of {char, codepoint, hex}
    """
    text = args.get("text", "")
    non_ascii = [(c, ord(c)) for c in text if ord(c) > 127]
    controls  = [(c, ord(c)) for c in text if ord(c) < 32 and c not in "\r\n\t"]

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

    return {
        "summary": buf.getvalue(),
        "non_ascii_count": len(non_ascii),
        "control_count":   len(controls),
        "non_ascii_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}"}
            for c, code in non_ascii
        ],
        "control_details": [
            {"char": c, "codepoint": code, "hex": f"U+{code:04X}"}
            for c, code in controls
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

function escHtml(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function render(data) {
  const results = document.getElementById('results');
  results.classList.remove('hidden');

  const naOk = data.non_ascii_count === 0;
  const ctOk = data.control_count   === 0;

  document.getElementById('stats').innerHTML = `
    <div class="stat">Length <span>${data.non_ascii_count + data.control_count + data.summary.split('\\n')[0].split(': ')[1]|0 }</span></div>
    <div class="stat">Non-ASCII <span class="${naOk?'tag-clean':'tag-warn'}">${data.non_ascii_count}</span></div>
    <div class="stat">Controls <span class="${ctOk?'tag-clean':'tag-warn'}">${data.control_count}</span></div>
  `;

  document.getElementById('summary').textContent = data.summary;

  const naSection = document.getElementById('non-ascii-section');
  if (data.non_ascii_details.length === 0) {
    naSection.classList.add('hidden');
  } else {
    naSection.classList.remove('hidden');
    document.getElementById('non-ascii-rows').innerHTML = data.non_ascii_details.map(row).join('');
  }

  const ctSection = document.getElementById('control-section');
  if (data.control_details.length === 0) {
    ctSection.classList.add('hidden');
  } else {
    ctSection.classList.remove('hidden');
    document.getElementById('control-rows').innerHTML = data.control_details.map(row).join('');
  }
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
            "non-ASCII, and control characters using a SPECTER-256-style analyzer."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": (
                        "The raw text to scan for hidden Unicode characters "
                        "and suspicious control characters."
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

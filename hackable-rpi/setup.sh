#!/usr/bin/env bash
# Hackable Raspberry Pi Simulator — Setup Script
# For cybersecurity training use only.

set -e

echo "============================================================"
echo "  Hackable Raspberry Pi Simulator — Setup"
echo "============================================================"

# Check Python 3
if ! command -v python3 &>/dev/null; then
  echo "[ERROR] Python 3 is required. Install it and retry."
  exit 1
fi

# Create virtualenv
if [ ! -d "venv" ]; then
  echo "[*] Creating virtual environment..."
  python3 -m venv venv
fi

# Install dependencies
echo "[*] Installing dependencies..."
./venv/bin/pip install -q -r requirements.txt

# Initialise database
echo "[*] Initialising database..."
./venv/bin/python -c "
import sys, os
sys.path.insert(0, os.path.dirname('$0'))
from app import init_db
init_db()
print('[*] Database ready.')
"

echo ""
echo "============================================================"
echo "  Setup complete!"
echo ""
echo "  Start the server:"
echo "    ./venv/bin/python app.py"
echo ""
echo "  Then open:  http://127.0.0.1:5000"
echo ""
echo "  Credentials:  admin / raspberry   (VULN-04)"
echo "                pi    / pi"
echo "============================================================"

#!/bin/bash
# Pentesting Profiler Setup Script
# Sets up the environment and dependencies for the pentesting profiler

echo "=========================================="
echo "Pentesting Profiler Setup"
echo "=========================================="
echo ""

# Check Python version
echo "[1/5] Checking Python version..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo "✓ Python 3 found: $PYTHON_VERSION"
else
    echo "✗ Python 3 not found. Please install Python 3.8 or higher."
    exit 1
fi

# Check and install system dependencies
echo ""
echo "[2/5] Checking system dependencies..."

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check nmap
if command_exists nmap; then
    echo "✓ nmap found"
else
    echo "✗ nmap not found"
    echo "  Install with:"
    echo "    Ubuntu/Debian: sudo apt install nmap"
    echo "    macOS: brew install nmap"
    echo "    Red Hat/CentOS: sudo yum install nmap"
fi

# Check dig
if command_exists dig; then
    echo "✓ dig found"
else
    echo "✗ dig not found"
    echo "  Install with:"
    echo "    Ubuntu/Debian: sudo apt install dnsutils"
    echo "    macOS: dig is pre-installed"
    echo "    Red Hat/CentOS: sudo yum install bind-utils"
fi

# Check whois
if command_exists whois; then
    echo "✓ whois found"
else
    echo "✗ whois not found"
    echo "  Install with:"
    echo "    Ubuntu/Debian: sudo apt install whois"
    echo "    macOS: whois is pre-installed"
    echo "    Red Hat/CentOS: sudo yum install whois"
fi

# Optional: Check theHarvester
if command_exists theHarvester; then
    echo "✓ theHarvester found (optional)"
else
    echo "○ theHarvester not found (optional)"
    echo "  Install with: sudo apt install theharvester"
fi

# Install Python dependencies
echo ""
echo "[3/5] Installing Python dependencies..."
if [ -f "requirements_profiler.txt" ]; then
    pip3 install -r requirements_profiler.txt
    if [ $? -eq 0 ]; then
        echo "✓ Python dependencies installed"
    else
        echo "✗ Failed to install Python dependencies"
        exit 1
    fi
else
    echo "✗ requirements_profiler.txt not found"
    exit 1
fi

# Make script executable
echo ""
echo "[4/5] Making profiler executable..."
chmod +x pentest_profiler.py
echo "✓ pentest_profiler.py is now executable"

# Create output directory
echo ""
echo "[5/5] Creating output directory..."
mkdir -p pentest_results
echo "✓ Output directory created: ./pentest_results"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  python3 pentest_profiler.py --target example.com"
echo ""
echo "For more information:"
echo "  cat PENTEST_PROFILER_README.md"
echo ""
echo "⚠️  Remember: Only use on authorized targets!"
echo ""

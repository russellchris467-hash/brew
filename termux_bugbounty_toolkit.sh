#!/data/data/com.termux/files/usr/bin/bash
# Termux Bug Bounty Toolkit Installer
# Professional security research tools for Termux on Android
# Optimized for ARM architecture and Android environment
# For authorized bug bounty research and security testing only

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track installed packages
INSTALLED_PKGS=""
FAILED_PKGS=""

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running in Termux
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        print_warning "This script is optimized for Termux on Android"
        print_info "Detected: $(uname -a)"
        echo ""
        read -p "Continue anyway? (y/n) " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Termux environment detected"
        print_info "Architecture: $(uname -m)"
    fi
}

# Update package repositories
update_repos() {
    print_header "UPDATING PACKAGE REPOSITORIES"

    # Update pkg (Termux package manager)
    if pkg update -y && pkg upgrade -y; then
        print_success "Repositories updated"
    else
        print_error "Failed to update repositories"
        exit 1
    fi
}

# Grant storage permission reminder
check_storage() {
    print_header "STORAGE PERMISSION CHECK"

    if [ ! -d "$HOME/storage" ]; then
        print_warning "Storage access not set up"
        print_info "Setting up storage access..."
        termux-setup-storage
        sleep 2
        print_success "Storage access configured"
    else
        print_success "Storage access already configured"
    fi
}

# Install package with error handling
install_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-20s${NC} ... " "$pkg"
    if pkg install -y "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS $pkg"
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS $pkg"
        return 1
    fi
}

# Install Python package
install_pip_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-20s${NC} ... " "$pkg"
    if pip install --no-cache-dir "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS pip:$pkg"
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS pip:$pkg"
        return 1
    fi
}

# Minimal installation (~100-200MB)
install_minimal() {
    print_header "MINIMAL TOOLKIT (~100-200MB)"
    print_info "Essential debugging and analysis tools for ARM"
    echo ""

    # Essential tools
    install_pkg "git"
    install_pkg "curl"
    install_pkg "wget"
    install_pkg "openssh"

    # Core debugging
    install_pkg "gdb"
    install_pkg "strace"
    install_pkg "ltrace"
    install_pkg "file"
    install_pkg "binutils"

    # Python for tooling
    install_pkg "python"
    install_pkg "python-pip"

    # Text processing
    install_pkg "vim"
    install_pkg "nano"
    install_pkg "less"
    install_pkg "grep"
    install_pkg "sed"

    # Essential utilities
    install_pkg "zip"
    install_pkg "unzip"
    install_pkg "tar"
    install_pkg "gzip"

    print_success "Minimal toolkit installation complete"
}

# Standard installation (~500MB-1GB)
install_standard() {
    print_header "STANDARD TOOLKIT (~500MB-1GB)"
    print_info "Complete bug bounty research environment"
    echo ""

    # Start with minimal
    install_minimal

    # Build tools
    install_pkg "clang"
    install_pkg "make"
    install_pkg "cmake"
    install_pkg "pkg-config"

    # Additional debugging
    install_pkg "valgrind" || print_warning "valgrind not available on ARM"
    install_pkg "hexdump"

    # Network analysis
    install_pkg "nmap"
    install_pkg "netcat"
    install_pkg "socat"
    install_pkg "tcpdump" || print_warning "tcpdump requires root"
    install_pkg "tsu" # Termux root access
    install_pkg "iproute2"

    # Reverse engineering
    install_pkg "radare2"
    install_pkg "objdump"
    install_pkg "readelf"
    install_pkg "strings"

    # Compression tools
    install_pkg "xz-utils"
    install_pkg "bzip2"
    install_pkg "p7zip"

    # Web tools
    install_pkg "w3m" # Text browser
    install_pkg "lynx" || print_warning "lynx not available"

    # Scripting
    install_pkg "nodejs"
    install_pkg "ruby"
    install_pkg "perl"

    # Python security tools
    print_info "Installing Python security packages..."
    install_pip_pkg "pwntools"
    install_pip_pkg "ropper"
    install_pip_pkg "capstone"
    install_pip_pkg "keystone-engine"
    install_pip_pkg "unicorn"
    install_pip_pkg "requests"
    install_pip_pkg "beautifulsoup4"

    print_success "Standard toolkit installation complete"
}

# Full installation (~1-2GB)
install_full() {
    print_header "FULL TOOLKIT (~1-2GB)"
    print_info "Everything including advanced research tools"
    echo ""

    # Start with standard
    install_standard

    # Advanced debugging
    install_pkg "lldb" || print_warning "lldb not available"
    install_pkg "gdb-multiarch" || print_warning "gdb-multiarch not available"

    # More network tools
    install_pkg "wireshark-cli" || install_pkg "tshark" || print_warning "wireshark not available"
    install_pkg "dnsutils"
    install_pkg "traceroute"
    install_pkg "whois"

    # Advanced reverse engineering
    install_pkg "rizin" || print_warning "rizin not available"
    install_pkg "cutter" || print_warning "cutter not available"

    # Exploitation tools
    install_pkg "metasploit" || print_warning "metasploit not in repos"

    # Mobile-specific tools
    install_pkg "apktool" || print_warning "apktool not available"
    install_pkg "aapt" || print_warning "aapt not available"

    # Fuzzing
    install_pkg "afl++" || print_warning "afl++ not available"
    install_pkg "honggfuzz" || print_warning "honggfuzz not available"

    # Additional scripting
    install_pkg "lua"
    install_pkg "php"

    # Additional Python tools
    install_pip_pkg "scapy"
    install_pip_pkg "impacket"
    install_pip_pkg "z3-solver" || print_warning "z3 may be slow to install"
    install_pip_pkg "angr" || print_warning "angr may not work on all ARM devices"
    install_pip_pkg "frida"
    install_pip_pkg "frida-tools"
    install_pip_pkg "objection"

    # Ruby tools
    gem install one_gadget 2>/dev/null || print_warning "one_gadget failed"

    print_success "Full toolkit installation complete"
}

# Install GEF (GDB Enhanced Features)
install_gef() {
    print_header "GDB ENHANCED FEATURES (GEF)"

    if ! command -v gdb >/dev/null 2>&1; then
        print_error "GDB not installed, skipping GEF"
        return 1
    fi

    print_info "Downloading GEF..."
    if wget -q -O ~/.gdbinit-gef.py https://github.com/hugsy/gef/raw/main/gef.py; then
        echo "source ~/.gdbinit-gef.py" > ~/.gdbinit
        print_success "GEF installed successfully"
        print_info "GEF will load automatically when you run gdb"
    else
        print_error "Failed to install GEF"
        return 1
    fi
}

# Install Pwndbg (alternative to GEF)
install_pwndbg() {
    print_header "PWNDBG (GDB PLUGIN)"

    if ! command -v gdb >/dev/null 2>&1; then
        print_error "GDB not installed, skipping Pwndbg"
        return 1
    fi

    print_info "Cloning Pwndbg..."
    if [ -d ~/pwndbg ]; then
        print_warning "Pwndbg already exists, updating..."
        cd ~/pwndbg && git pull
    else
        git clone https://github.com/pwndbg/pwndbg ~/pwndbg
    fi

    cd ~/pwndbg
    ./setup.sh
    print_success "Pwndbg installed successfully"
}

# Create verification script
create_verification() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > ~/check_termux_tools.sh << 'VERIFY_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Termux Bug Bounty Tools Verification Script

echo "=== Termux Bug Bounty Toolkit Verification ==="
echo ""

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "%-20s: \033[0;32m✓ installed\033[0m\n" "$1"
        return 0
    else
        printf "%-20s: \033[0;31m✗ missing\033[0m\n" "$1"
        return 1
    fi
}

echo "Core Tools:"
check_tool gdb
check_tool strace
check_tool ltrace
check_tool file
check_tool objdump
check_tool readelf
check_tool strings
echo ""

echo "Network Tools:"
check_tool nmap
check_tool nc
check_tool socat
check_tool tcpdump
echo ""

echo "Analysis Tools:"
check_tool radare2
check_tool r2
check_tool hexdump
echo ""

echo "Python Packages:"
python -c "import pwn; print('pwntools          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "pwntools          : \033[0;31m✗ missing\033[0m"
python -c "import ropper; print('ropper            : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "ropper            : \033[0;31m✗ missing\033[0m"
python -c "import capstone; print('capstone          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "capstone          : \033[0;31m✗ missing\033[0m"
python -c "import keystone; print('keystone          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "keystone          : \033[0;31m✗ missing\033[0m"
python -c "import unicorn; print('unicorn           : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "unicorn           : \033[0;31m✗ missing\033[0m"
python -c "import frida; print('frida             : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "frida             : \033[0;31m✗ missing\033[0m"
echo ""

if [ -f ~/.gdbinit-gef.py ]; then
    echo "GEF               : \033[0;32m✓ installed\033[0m"
elif [ -d ~/pwndbg ]; then
    echo "Pwndbg            : \033[0;32m✓ installed\033[0m"
else
    echo "GDB Enhancement   : \033[0;31m✗ not installed\033[0m"
fi
echo ""

echo "Architecture      : $(uname -m)"
echo "Termux Version    : $(termux-info | grep TERMUX_VERSION | cut -d'=' -f2)"
echo ""

echo "=== Verification Complete ==="
VERIFY_EOF

    chmod +x ~/check_termux_tools.sh
    print_success "Verification script created: ~/check_termux_tools.sh"
}

# Create quick start guide
create_quickstart() {
    print_header "CREATING QUICK START GUIDE"

    cat > ~/termux_bugbounty_quickstart.md << 'GUIDE_EOF'
# Termux Bug Bounty Quick Start Guide

## Essential Commands

### Debugging with GDB
```bash
# Debug a binary
gdb ./program

# With GEF or Pwndbg (auto-loads)
gdb ./program

# Common commands
(gdb) run
(gdb) break main
(gdb) continue
(gdb) info registers
(gdb) x/20x $sp
(gdb) disas main
```

### System Analysis
```bash
# Trace system calls
strace ./program

# Trace library calls
ltrace ./program

# Check file type
file binary

# View strings
strings binary | less

# Hexdump
hexdump -C binary | less
```

### Reverse Engineering with Radare2
```bash
r2 ./binary
[0x00000000]> aa    # Analyze
[0x00000000]> afl   # List functions
[0x00000000]> pdf @main  # Disassemble
[0x00000000]> VV    # Visual mode
```

### Network Analysis
```bash
# Port scan
nmap -sV target.com

# Netcat listener
nc -l -p 4444

# Connect to service
nc target.com 80

# Capture packets (requires root)
su -c "tcpdump -i wlan0 port 80"
```

### Python Exploitation (Pwntools)
```python
#!/data/data/com.termux/files/usr/bin/python
from pwn import *

# Connect to service
r = remote('target.com', 1337)

# Or local process
r = process('./vulnerable')

# Send payload
payload = b'A' * 64
r.sendline(payload)

# Interactive
r.interactive()
```

### Mobile App Analysis
```bash
# Decompile APK (if apktool installed)
apktool d app.apk

# Analyze with Frida
frida -U -f com.example.app

# Objection (Frida wrapper)
objection -g com.example.app explore
```

## Termux-Specific Features

### Storage Access
```bash
# Setup storage access
termux-setup-storage

# Access Downloads
cd ~/storage/downloads

# Access shared storage
cd ~/storage/shared
```

### Sharing Files
```bash
# Start HTTP server
python -m http.server 8000

# Share via termux-share
termux-share file.txt

# Open file in Android app
termux-open file.pdf
```

### Clipboard
```bash
# Copy to clipboard
echo "data" | termux-clipboard-set

# Paste from clipboard
termux-clipboard-get
```

### Notifications
```bash
# Send notification
termux-notification -t "Scan Complete" -c "Found 5 open ports"
```

### Wake Lock
```bash
# Prevent sleep during long tasks
termux-wake-lock

# Release wake lock
termux-wake-unlock
```

## Android Permissions

Some tools require root access:
```bash
# Install tsu (Termux SuperUser)
pkg install tsu

# Switch to root (requires rooted device)
tsu

# Or run single command
tsu -c "tcpdump -i wlan0"
```

## Tips

- Native ARM performance (faster than iSH x86 emulation)
- Access Android filesystem via ~/storage
- Use termux-api for Android integration
- Install Termux:API app for extended features
- Use Termux:Boot for background services

Happy hunting! 🎯📱
GUIDE_EOF

    print_success "Quick start guide created: ~/termux_bugbounty_quickstart.md"
}

# Installation summary
print_summary() {
    print_header "INSTALLATION SUMMARY"

    echo -e "${GREEN}Successfully Installed:${NC}"
    for pkg in $INSTALLED_PKGS; do
        echo "  ✓ $pkg"
    done
    echo ""

    if [ -n "$FAILED_PKGS" ]; then
        echo -e "${RED}Failed to Install:${NC}"
        for pkg in $FAILED_PKGS; do
            echo "  ✗ $pkg"
        done
        echo ""
        print_warning "Some packages failed - this is normal on Termux"
    fi

    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Run verification: ${YELLOW}~/check_termux_tools.sh${NC}"
    echo "  2. Read guide: ${YELLOW}cat ~/termux_bugbounty_quickstart.md${NC}"
    echo "  3. Test GDB: ${YELLOW}gdb --version${NC}"
    echo "  4. Test pwntools: ${YELLOW}python -c 'import pwn; print(pwn.__version__)'${NC}"
    echo ""

    print_info "Termux-specific tips:"
    echo "  • Use 'termux-setup-storage' for file access"
    echo "  • Install 'Termux:API' app for Android features"
    echo "  • Use 'pkg search <name>' to find packages"
    echo "  • Architecture: $(uname -m) (native ARM performance!)"
    echo ""

    print_success "Termux Bug Bounty Toolkit installation complete! 🎯📱"
}

# Main menu
show_menu() {
    print_header "TERMUX BUG BOUNTY TOOLKIT INSTALLER"
    echo "Optimized for Android ARM Architecture"
    echo ""
    echo "Choose installation profile:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Minimal   (~100-200MB) - Essential debugging tools"
    echo -e "  ${BLUE}2)${NC} Standard  (~500MB-1GB) - Complete toolkit ${YELLOW}[DEFAULT]${NC}"
    echo -e "  ${PURPLE}3)${NC} Full      (~1-2GB)     - Everything + mobile tools"
    echo -e "  ${CYAN}4)${NC} GEF Only  - Install GDB Enhanced Features only"
    echo -e "  ${CYAN}5)${NC} Pwndbg    - Install Pwndbg GDB plugin"
    echo -e "  ${RED}6)${NC} Exit"
    echo ""
    printf "Select option [1-6] (default: 2): "
}

# Main execution
main() {
    check_termux
    check_storage

    # Parse command line arguments
    case "$1" in
        --minimal)
            update_repos
            install_minimal
            install_gef
            create_verification
            create_quickstart
            print_summary
            exit 0
            ;;
        --standard|"")
            update_repos
            install_standard
            install_gef
            create_verification
            create_quickstart
            print_summary
            exit 0
            ;;
        --full)
            update_repos
            install_full
            install_gef
            create_verification
            create_quickstart
            print_summary
            exit 0
            ;;
        --gef-only)
            install_gef
            exit 0
            ;;
        --pwndbg-only)
            install_pwndbg
            exit 0
            ;;
        --help|-h)
            echo "Termux Bug Bounty Toolkit Installer"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --minimal      Install minimal toolkit (~100-200MB)"
            echo "  --standard     Install standard toolkit (~500MB-1GB) [DEFAULT]"
            echo "  --full         Install full toolkit (~1-2GB)"
            echo "  --gef-only     Install GEF only"
            echo "  --pwndbg-only  Install Pwndbg only"
            echo "  --help         Show this help message"
            echo ""
            exit 0
            ;;
        *)
            # Interactive menu
            show_menu
            read -r choice
            case ${choice:-2} in
                1)
                    update_repos
                    install_minimal
                    install_gef
                    create_verification
                    create_quickstart
                    print_summary
                    ;;
                2)
                    update_repos
                    install_standard
                    install_gef
                    create_verification
                    create_quickstart
                    print_summary
                    ;;
                3)
                    update_repos
                    install_full
                    install_gef
                    create_verification
                    create_quickstart
                    print_summary
                    ;;
                4)
                    install_gef
                    ;;
                5)
                    install_pwndbg
                    ;;
                6)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option"
                    exit 1
                    ;;
            esac
            ;;
    esac
}

# Run main function
main "$@"

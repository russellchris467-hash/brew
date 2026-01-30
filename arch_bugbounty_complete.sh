#!/bin/bash
# 🐧 Arch Linux Bug Bounty Toolkit - Complete Installer
# Purpose: Install all bug bounty research tools on Arch Linux
# Usage: bash arch_bugbounty_complete.sh [--minimal|--standard|--full]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Don't run as root! Script will use sudo when needed."
        exit 1
    fi
}

install_pkg() {
    local pkg=$1
    if pacman -Qi "$pkg" &>/dev/null; then
        print_info "$pkg already installed"
    else
        echo -n "Installing $pkg... "
        if sudo pacman -S --noconfirm --needed "$pkg" &>/dev/null; then
            print_success "$pkg"
        else
            print_warning "$pkg failed (may not be available)"
        fi
    fi
}

install_pip_pkg() {
    local pkg=$1
    echo -n "Installing Python: $pkg... "
    if pip install --user --break-system-packages "$pkg" &>/dev/null 2>&1 || \
       pip install --user "$pkg" &>/dev/null 2>&1; then
        print_success "$pkg"
    else
        print_warning "$pkg failed"
    fi
}

# Installation profiles
install_minimal() {
    print_header "MINIMAL BUG BOUNTY TOOLKIT"

    print_info "Core Debugging Tools"
    install_pkg "gdb"
    install_pkg "strace"
    install_pkg "valgrind"

    print_info "Basic Analysis"
    install_pkg "binutils"
    install_pkg "file"

    print_info "Build Tools"
    install_pkg "base-devel"
    install_pkg "git"

    print_info "Python Environment"
    install_pkg "python"
    install_pkg "python-pip"
    install_pip_pkg "pwntools"

    print_success "Minimal installation complete!"
}

install_standard() {
    print_header "STANDARD BUG BOUNTY TOOLKIT"

    print_info "Core Debugging Tools"
    install_pkg "gdb"
    install_pkg "lldb"
    install_pkg "strace"
    install_pkg "ltrace"
    install_pkg "valgrind"

    print_info "Reverse Engineering"
    install_pkg "radare2"
    install_pkg "cutter"
    install_pkg "binutils"
    install_pkg "binwalk"
    install_pkg "checksec"

    print_info "Network Analysis"
    install_pkg "wireshark-cli"
    install_pkg "tcpdump"
    install_pkg "nmap"
    install_pkg "socat"
    install_pkg "gnu-netcat"

    print_info "Binary Analysis"
    install_pkg "capstone"
    install_pkg "python-capstone"

    print_info "Build Tools"
    install_pkg "base-devel"
    install_pkg "cmake"
    install_pkg "git"
    install_pkg "gcc"
    install_pkg "clang"

    print_info "Python Security Tools"
    install_pkg "python"
    install_pkg "python-pip"
    install_pip_pkg "pwntools"
    install_pip_pkg "ropper"
    install_pip_pkg "capstone"
    install_pip_pkg "keystone-engine"

    print_success "Standard installation complete!"
}

install_full() {
    print_header "FULL BUG BOUNTY TOOLKIT"

    print_info "Core Debugging Tools"
    install_pkg "gdb"
    install_pkg "lldb"
    install_pkg "strace"
    install_pkg "ltrace"
    install_pkg "valgrind"

    print_info "Reverse Engineering"
    install_pkg "radare2"
    install_pkg "cutter"
    install_pkg "binutils"
    install_pkg "binwalk"
    install_pkg "checksec"
    install_pkg "patchelf"
    install_pkg "upx"
    install_pkg "ropgadget"

    print_info "Fuzzing Tools"
    install_pkg "afl++"
    install_pkg "honggfuzz"

    print_info "Network Analysis"
    install_pkg "wireshark-qt"
    install_pkg "wireshark-cli"
    install_pkg "tcpdump"
    install_pkg "nmap"
    install_pkg "socat"
    install_pkg "gnu-netcat"
    install_pkg "openbsd-netcat"

    print_info "Web Security"
    install_pkg "sqlmap"

    print_info "Binary Analysis"
    install_pkg "capstone"
    install_pkg "keystone"
    install_pkg "unicorn"
    install_pkg "python-capstone"

    print_info "Performance Analysis"
    install_pkg "perf"
    install_pkg "heaptrack"

    print_info "Container Tools"
    install_pkg "docker"
    install_pkg "docker-compose"
    install_pkg "bubblewrap"

    print_info "Build Tools"
    install_pkg "base-devel"
    install_pkg "cmake"
    install_pkg "meson"
    install_pkg "git"
    install_pkg "gcc"
    install_pkg "clang"
    install_pkg "llvm"

    print_info "Utilities"
    install_pkg "hexedit"
    install_pkg "vim"
    install_pkg "file"
    install_pkg "diffutils"
    install_pkg "wget"
    install_pkg "curl"

    print_info "Python Security Tools"
    install_pkg "python"
    install_pkg "python-pip"
    install_pip_pkg "pwntools"
    install_pip_pkg "ropper"
    install_pip_pkg "capstone"
    install_pip_pkg "keystone-engine"
    install_pip_pkg "unicorn"
    install_pip_pkg "angr"
    install_pip_pkg "z3-solver"
    install_pip_pkg "ROPgadget"

    print_info "Ruby Security Tools"
    install_pkg "ruby"
    echo -n "Installing Ruby: one_gadget... "
    if gem install --user-install one_gadget &>/dev/null; then
        print_success "one_gadget"
    else
        print_warning "one_gadget failed"
    fi

    print_success "Full installation complete!"
}

install_gef() {
    print_header "INSTALLING GDB ENHANCEMENTS"

    print_info "Installing GEF (GDB Enhanced Features)..."
    if bash -c "$(curl -fsSL https://gef.blah.cat/sh)" 2>/dev/null; then
        print_success "GEF installed!"
    else
        print_warning "GEF installation failed"
        print_info "Manual install: bash -c \"\$(curl -fsSL https://gef.blah.cat/sh)\""
    fi
}

create_verification_script() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > ~/check_bugbounty_tools.sh << 'VERIFY_EOF'
#!/bin/bash
# Bug Bounty Toolkit Verification

echo "🔍 Checking Bug Bounty Toolkit Installation"
echo "============================================"
echo

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "✅ $1"
        return 0
    else
        echo "❌ $1"
        return 1
    fi
}

check_python() {
    if python3 -c "import $1" 2>/dev/null; then
        echo "✅ Python: $1"
        return 0
    else
        echo "❌ Python: $1"
        return 1
    fi
}

echo "Core Debugging:"
check_cmd gdb
check_cmd strace
check_cmd valgrind
check_cmd ltrace
echo

echo "Reverse Engineering:"
check_cmd radare2
check_cmd objdump
check_cmd checksec
echo

echo "Network Tools:"
check_cmd nmap
check_cmd tcpdump
check_cmd wireshark
echo

echo "Fuzzing:"
check_cmd afl-fuzz
check_cmd honggfuzz
echo

echo "Binary Analysis:"
check_cmd binwalk
check_cmd patchelf
echo

echo "Python Tools:"
check_python pwn
check_python ropper
check_python capstone
check_python keystone
check_python unicorn
echo

echo "Build Tools:"
check_cmd gcc
check_cmd make
check_cmd git
echo

echo "Container Tools:"
check_cmd docker
check_cmd bwrap
echo

echo "============================================"
echo "✅ Verification complete!"
echo
echo "Test with:"
echo "  gdb --version"
echo "  python3 -c 'from pwn import *; print(cyclic(20))'"
VERIFY_EOF

    chmod +x ~/check_bugbounty_tools.sh
    print_success "Verification script: ~/check_bugbounty_tools.sh"
}

create_quick_start_guide() {
    print_header "CREATING QUICK START GUIDE"

    cat > ~/bugbounty_quickstart.md << 'GUIDE_EOF'
# 🎯 Bug Bounty Quick Start Guide

## Essential Commands

### Debugging
```bash
# Debug a binary
gdb ./program
(gdb) run
(gdb) backtrace
(gdb) info registers

# Trace system calls
strace ./program
strace -e open,read,write ./program

# Memory debugging
valgrind --leak-check=full ./program
```

### Reverse Engineering
```bash
# Radare2 analysis
r2 ./binary
aa              # Analyze
afl             # List functions
pdf @main       # Disassemble main

# Check security features
checksec --file=./binary

# Binwalk for firmware
binwalk firmware.bin
binwalk -e firmware.bin  # Extract
```

### Network Analysis
```bash
# Port scanning
nmap -sV target.com
nmap -p- target.com

# Packet capture
sudo tcpdump -i eth0 -w capture.pcap
wireshark capture.pcap

# Network debugging
nc -lvp 4444
socat TCP-LISTEN:8080,fork TCP:target:80
```

### Fuzzing
```bash
# AFL fuzzing
afl-gcc program.c -o program
mkdir inputs outputs
echo "test" > inputs/seed
afl-fuzz -i inputs -o outputs ./program @@

# Honggfuzz
honggfuzz -i inputs -o outputs -- ./program ___FILE___
```

### Python Exploitation
```bash
# Pwntools
python3 << 'EOF'
from pwn import *

# Generate pattern
pattern = cyclic(100)
print(pattern)

# Find offset
offset = cyclic_find(0x61616161)
print(f"Offset: {offset}")

# Shellcode
shellcode = asm(shellcraft.sh())
print(hexdump(shellcode))
EOF
```

### Binary Analysis
```bash
# ROPgadget
ROPgadget --binary ./program

# One_gadget
one_gadget /lib/x86_64-linux-gnu/libc.so.6

# Ropper
ropper --file ./program --search "pop rdi"
```

## Bug Bounty Workflow

1. **Reconnaissance**
   ```bash
   nmap -sV target.com
   ./vm-research/hypervisor_enum.rb
   ```

2. **Analysis**
   ```bash
   r2 ./target_binary
   checksec ./target_binary
   ```

3. **Fuzzing**
   ```bash
   afl-fuzz -i inputs -o crashes ./target
   ```

4. **Exploitation**
   ```bash
   python3 exploit.py
   ```

5. **Report**
   ```bash
   ./disclosure/poc_builder.rb --new "Vulnerability Title"
   ```

## Resources

- GDB manual: `man gdb`
- Radare2 book: https://book.rada.re/
- Pwntools docs: https://docs.pwntools.com/
GUIDE_EOF

    print_success "Quick start guide: ~/bugbounty_quickstart.md"
}

post_install() {
    print_header "POST-INSTALLATION"

    echo
    read -p "Install GDB enhancements (GEF)? [Y/n]: " gef
    [[ "$gef" =~ ^[Yy]$ ]] || [[ -z "$gef" ]] && install_gef

    echo
    read -p "Create verification script? [Y/n]: " verify
    [[ "$verify" =~ ^[Yy]$ ]] || [[ -z "$verify" ]] && create_verification_script

    echo
    read -p "Create quick start guide? [Y/n]: " guide
    [[ "$guide" =~ ^[Yy]$ ]] || [[ -z "$guide" ]] && create_quick_start_guide

    print_header "INSTALLATION COMPLETE!"
    echo
    print_success "Bug bounty toolkit installed successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Run: ~/check_bugbounty_tools.sh"
    echo "  2. Read: ~/bugbounty_quickstart.md"
    echo "  3. Start hunting bugs! 🎯"
    echo
    print_info "For UTM/VM research:"
    echo "  cd bug-bounty-toolkit"
    echo "  ./vm-research/hypervisor_enum.rb"
    echo
}

show_menu() {
    clear
    print_header "ARCH LINUX BUG BOUNTY TOOLKIT INSTALLER"
    echo
    echo "Choose installation profile:"
    echo
    echo "  1) Minimal    - Core tools only (~200MB)"
    echo "  2) Standard   - Common tools (~1GB) [RECOMMENDED]"
    echo "  3) Full       - Everything (~3GB)"
    echo "  4) GEF Only   - Just GDB enhancements"
    echo "  5) Exit"
    echo
    read -p "Select option [1-5]: " choice

    case $choice in
        1) install_minimal; post_install ;;
        2) install_standard; post_install ;;
        3) install_full; post_install ;;
        4) install_gef ;;
        5) exit 0 ;;
        *) print_error "Invalid option"; sleep 2; show_menu ;;
    esac
}

# Main execution
main() {
    check_root

    print_header "ARCH LINUX BUG BOUNTY TOOLKIT"
    echo
    print_info "This will install tools for authorized bug bounty research"
    print_info "Updating package database..."
    sudo pacman -Sy

    if [ $# -eq 0 ]; then
        show_menu
    else
        case "$1" in
            --minimal)
                install_minimal
                post_install
                ;;
            --standard)
                install_standard
                post_install
                ;;
            --full)
                install_full
                post_install
                ;;
            --gef-only)
                install_gef
                ;;
            --help|-h)
                echo "Usage: $0 [--minimal|--standard|--full|--gef-only]"
                echo
                echo "Options:"
                echo "  --minimal   Core debugging tools (~200MB)"
                echo "  --standard  Common bug bounty tools (~1GB) [RECOMMENDED]"
                echo "  --full      Complete toolkit (~3GB)"
                echo "  --gef-only  Just install GDB Enhanced Features"
                echo "  --help      Show this help"
                echo
                echo "No arguments: Interactive menu"
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage"
                exit 1
                ;;
        esac
    fi
}

main "$@"

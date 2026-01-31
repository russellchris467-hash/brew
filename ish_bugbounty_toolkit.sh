#!/bin/sh
# iSH Bug Bounty Toolkit Installer
# Professional security research tools for iSH (iOS Alpine Linux)
# Optimized for limited resources and Alpine Linux environment
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
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${PURPLE}  $1${NC}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

print_warning() {
    echo "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo "${BLUE}ℹ${NC} $1"
}

# Check if running in iSH
check_ish() {
    if [ ! -f /proc/ish/version ] && [ ! -f /proc/version ]; then
        print_warning "This script is optimized for iSH on iOS"
        print_info "Detected: $(uname -a)"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "iSH environment detected"
    fi
}

# Update package repositories
update_repos() {
    print_header "UPDATING PACKAGE REPOSITORIES"
    if apk update; then
        print_success "Repositories updated"
    else
        print_error "Failed to update repositories"
        exit 1
    fi
}

# Install package with error handling
install_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-20s${NC} ... " "$pkg"
    if apk add --no-cache "$pkg" >/dev/null 2>&1; then
        echo "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS $pkg"
        return 0
    else
        echo "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS $pkg"
        return 1
    fi
}

# Install Python package
install_pip_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-20s${NC} ... " "$pkg"
    if pip3 install --no-cache-dir "$pkg" >/dev/null 2>&1; then
        echo "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS pip:$pkg"
        return 0
    else
        echo "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS pip:$pkg"
        return 1
    fi
}

# Minimal installation (essential tools only - ~50-100MB)
install_minimal() {
    print_header "MINIMAL TOOLKIT (~50-100MB)"
    print_info "Core debugging and analysis tools"
    echo ""

    # Essential build tools
    install_pkg "build-base"
    install_pkg "git"
    install_pkg "curl"
    install_pkg "wget"

    # Core debugging
    install_pkg "gdb"
    install_pkg "strace"
    install_pkg "ltrace" || print_warning "ltrace not available"
    install_pkg "file"
    install_pkg "binutils"

    # Python for tooling
    install_pkg "python3"
    install_pkg "py3-pip"

    # Text processing
    install_pkg "vim"
    install_pkg "less"
    install_pkg "grep"
    install_pkg "sed"

    print_success "Minimal toolkit installation complete"
}

# Standard installation (recommended - ~200-500MB)
install_standard() {
    print_header "STANDARD TOOLKIT (~200-500MB)"
    print_info "Recommended for bug bounty research"
    echo ""

    # Start with minimal
    install_minimal

    # Additional debugging tools
    install_pkg "valgrind" || print_warning "valgrind not available on this arch"
    install_pkg "hexdump"
    install_pkg "xxd"

    # Network analysis
    install_pkg "tcpdump"
    install_pkg "nmap"
    install_pkg "netcat-openbsd"
    install_pkg "socat" || print_warning "socat not available"
    install_pkg "openssh-client"

    # Reverse engineering basics
    install_pkg "radare2" || print_warning "radare2 not in main repos"
    install_pkg "objdump"
    install_pkg "readelf"
    install_pkg "strings"

    # Compression/archive tools
    install_pkg "unzip"
    install_pkg "tar"
    install_pkg "gzip"
    install_pkg "bzip2"
    install_pkg "xz"

    # Python security tools
    print_info "Installing Python security packages..."
    install_pip_pkg "pwntools"
    install_pip_pkg "ropper"
    install_pip_pkg "capstone"
    install_pip_pkg "keystone-engine" || print_warning "keystone-engine may fail on Alpine"

    print_success "Standard toolkit installation complete"
}

# Full installation (everything - ~500MB-1GB)
install_full() {
    print_header "FULL TOOLKIT (~500MB-1GB)"
    print_info "Complete bug bounty research environment"
    echo ""

    # Start with standard
    install_standard

    # Advanced debugging
    install_pkg "lldb" || print_warning "lldb not available"

    # Additional network tools
    install_pkg "wireshark-common" || install_pkg "tshark"
    install_pkg "bind-tools"
    install_pkg "iproute2"
    install_pkg "iptables"

    # Web tools
    install_pkg "curl-dev"
    install_pkg "openssl"
    install_pkg "openssl-dev"

    # Development tools
    install_pkg "cmake"
    install_pkg "make"
    install_pkg "gcc"
    install_pkg "g++"
    install_pkg "clang" || print_warning "clang not available"

    # Scripting languages
    install_pkg "bash"
    install_pkg "perl"
    install_pkg "ruby" || print_warning "ruby not available"

    # Additional Python tools
    install_pip_pkg "requests"
    install_pip_pkg "beautifulsoup4"
    install_pip_pkg "scapy" || print_warning "scapy may have issues"
    install_pip_pkg "unicorn" || print_warning "unicorn may fail on Alpine"
    install_pip_pkg "z3-solver" || print_warning "z3 may fail on Alpine"

    # Binary analysis
    install_pkg "upx" || print_warning "upx not available"
    install_pkg "patchelf" || print_warning "patchelf not available"

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

# Create verification script
create_verification() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > ~/check_ish_tools.sh << 'VERIFY_EOF'
#!/bin/sh
# iSH Bug Bounty Tools Verification Script

echo "=== iSH Bug Bounty Toolkit Verification ==="
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
check_tool tcpdump
check_tool nmap
check_tool nc
check_tool socat
echo ""

echo "Analysis Tools:"
check_tool radare2
check_tool r2
check_tool xxd
check_tool hexdump
echo ""

echo "Python Packages:"
python3 -c "import pwn; print('pwntools          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "pwntools          : \033[0;31m✗ missing\033[0m"
python3 -c "import ropper; print('ropper            : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "ropper            : \033[0;31m✗ missing\033[0m"
python3 -c "import capstone; print('capstone          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "capstone          : \033[0;31m✗ missing\033[0m"
python3 -c "import keystone; print('keystone          : \033[0;32m✓ installed\033[0m')" 2>/dev/null || echo "keystone          : \033[0;31m✗ missing\033[0m"
echo ""

if [ -f ~/.gdbinit-gef.py ]; then
    echo "GEF               : \033[0;32m✓ installed\033[0m"
else
    echo "GEF               : \033[0;31m✗ not installed\033[0m"
fi
echo ""

echo "=== Verification Complete ==="
VERIFY_EOF

    chmod +x ~/check_ish_tools.sh
    print_success "Verification script created: ~/check_ish_tools.sh"
}

# Create quick start guide
create_quickstart() {
    print_header "CREATING QUICK START GUIDE"

    cat > ~/ish_bugbounty_quickstart.md << 'GUIDE_EOF'
# iSH Bug Bounty Quick Start Guide

## Essential Commands

### Debugging with GDB
```bash
# Debug a binary
gdb ./vulnerable_program

# With GEF (if installed)
gdb ./program
# GEF loads automatically

# Common GDB commands
(gdb) run              # Run the program
(gdb) break main       # Set breakpoint at main
(gdb) continue         # Continue execution
(gdb) info registers   # Show registers
(gdb) x/10x $rsp      # Examine stack
(gdb) disas main       # Disassemble main
```

### System Analysis
```bash
# Trace system calls
strace ./program

# Trace library calls
ltrace ./program

# Check binary properties
file binary
checksec binary  # If installed

# View strings
strings binary | less

# Hexdump
xxd binary | less
hexdump -C binary | less
```

### Reverse Engineering
```bash
# Radare2 (if installed)
r2 ./binary
[0x00000000]> aa   # Analyze all
[0x00000000]> afl  # List functions
[0x00000000]> pdf @main  # Disassemble main
[0x00000000]> VV   # Visual graph mode

# Objdump
objdump -d binary  # Disassemble
objdump -t binary  # Symbol table
objdump -x binary  # All headers

# Readelf
readelf -h binary  # ELF header
readelf -l binary  # Program headers
readelf -S binary  # Section headers
```

### Network Analysis
```bash
# Scan ports
nmap -sV target_ip
nmap -p- localhost

# Capture packets (may need root)
tcpdump -i any port 80

# Netcat listener
nc -l -p 4444

# Connect to service
nc target_ip 80

# Socat (if installed)
socat TCP-LISTEN:8080,fork TCP:target:80
```

### Python Exploitation (Pwntools)
```python
#!/usr/bin/env python3
from pwn import *

# Connect to service
r = remote('target', 1337)

# Or debug locally
r = process('./vulnerable')

# Send payload
payload = b'A' * 64
r.sendline(payload)

# Receive data
data = r.recvline()
print(data)

# Interactive shell
r.interactive()
```

### Finding ROP Gadgets
```bash
# With ropper
ropper --file binary --search "pop rdi"

# With objdump
objdump -d binary | grep -A 3 "pop.*ret"
```

### Binary Analysis
```python
# Capstone disassembly
from capstone import *

md = Cs(CS_ARCH_X86, CS_MODE_64)
for i in md.disasm(code, 0x1000):
    print("0x%x:\t%s\t%s" % (i.address, i.mnemonic, i.op_str))
```

## Bug Bounty Workflow

### 1. Reconnaissance
```bash
# Identify target
file target
strings target | grep -i version

# Check for vulnerabilities
checksec target
```

### 2. Dynamic Analysis
```bash
# Run with debugger
gdb ./target

# Trace execution
strace -f ./target
```

### 3. Fuzzing (Manual)
```bash
# Generate patterns
python3 -c "print('A'*100)" | ./target

# With pwntools
from pwn import cyclic
print(cyclic(200))
```

### 4. Exploitation
```python
# Build exploit with pwntools
from pwn import *

context.binary = './target'
r = process('./target')

payload = fit({
    64: p64(0xdeadbeef)  # Overwrite return address
})

r.sendline(payload)
r.interactive()
```

### 5. Documentation
```bash
# Capture proof of concept
script poc_session.log
# ... perform exploit ...
exit
```

## iSH-Specific Tips

### Storage Management
```bash
# Check disk space
df -h

# Clean package cache
apk cache clean

# Remove unused packages
apk del package_name
```

### Performance
- iSH runs x86 emulation, expect slower performance
- Use minimal tools when possible
- Avoid heavy GUI tools
- Work with smaller binaries

### Limitations
- Some tools may not be available in Alpine repos
- musl libc instead of glibc (different behavior)
- No systemd (uses OpenRC)
- Limited memory on iOS devices
- Some kernel features unavailable

### Package Management
```bash
# Search for packages
apk search keyword

# Get package info
apk info package_name

# Update all packages
apk upgrade

# List installed packages
apk list --installed
```

## Useful Resources

- **Apple Security Bounty**: https://support.apple.com/en-us/HT201220
- **iSH Project**: https://github.com/ish-app/ish
- **Pwntools Docs**: https://docs.pwntools.com/
- **GEF Documentation**: https://hugsy.github.io/gef/

## Verification

Run the verification script:
```bash
~/check_ish_tools.sh
```

## Notes

⚠️ For authorized security research and bug bounty programs only
⚠️ Always follow responsible disclosure practices
⚠️ Respect program terms and conditions
⚠️ iSH runs in iOS sandbox - limited capabilities

Happy hunting! 🎯💰
GUIDE_EOF

    print_success "Quick start guide created: ~/ish_bugbounty_quickstart.md"
}

# Installation summary
print_summary() {
    print_header "INSTALLATION SUMMARY"

    echo "${GREEN}Successfully Installed:${NC}"
    for pkg in $INSTALLED_PKGS; do
        echo "  ✓ $pkg"
    done
    echo ""

    if [ -n "$FAILED_PKGS" ]; then
        echo "${RED}Failed to Install:${NC}"
        for pkg in $FAILED_PKGS; do
            echo "  ✗ $pkg"
        done
        echo ""
        print_warning "Some packages failed - this is normal on iSH/Alpine"
    fi

    echo "${CYAN}Next Steps:${NC}"
    echo "  1. Run verification: ${YELLOW}~/check_ish_tools.sh${NC}"
    echo "  2. Read guide: ${YELLOW}less ~/ish_bugbounty_quickstart.md${NC}"
    echo "  3. Test GDB: ${YELLOW}gdb --version${NC}"
    echo "  4. Test pwntools: ${YELLOW}python3 -c 'import pwn; print(pwn.__version__)'${NC}"
    echo ""
    print_success "iSH Bug Bounty Toolkit installation complete! 🎯"
}

# Main menu
show_menu() {
    print_header "iSH BUG BOUNTY TOOLKIT INSTALLER"
    echo "Optimized for iSH (iOS Alpine Linux Environment)"
    echo ""
    echo "Choose installation profile:"
    echo ""
    echo "  ${GREEN}1)${NC} Minimal   (~50-100MB)  - Essential debugging tools"
    echo "  ${BLUE}2)${NC} Standard  (~200-500MB) - Recommended for bug bounty ${YELLOW}[DEFAULT]${NC}"
    echo "  ${PURPLE}3)${NC} Full      (~500MB-1GB) - Complete research toolkit"
    echo "  ${CYAN}4)${NC} GEF Only  - Install GDB Enhanced Features only"
    echo "  ${RED}5)${NC} Exit"
    echo ""
    printf "Select option [1-5] (default: 2): "
}

# Main execution
main() {
    check_ish

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
        --help|-h)
            echo "iSH Bug Bounty Toolkit Installer"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --minimal    Install minimal toolkit (~50-100MB)"
            echo "  --standard   Install standard toolkit (~200-500MB) [DEFAULT]"
            echo "  --full       Install full toolkit (~500MB-1GB)"
            echo "  --gef-only   Install GEF only"
            echo "  --help       Show this help message"
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

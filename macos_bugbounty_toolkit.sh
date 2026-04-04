#!/bin/bash
# macOS Bug Bounty Toolkit Installer
# Professional security research tools using Homebrew
# For authorized bug bounty research and security testing only
# Optimized for macOS (Intel & Apple Silicon)

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

# Check if Homebrew is installed
check_homebrew() {
    print_header "CHECKING HOMEBREW"

    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew not found"
        print_info "Installing Homebrew..."

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if command -v brew >/dev/null 2>&1; then
            print_success "Homebrew installed successfully"
        else
            print_error "Failed to install Homebrew"
            exit 1
        fi
    else
        print_success "Homebrew found: $(brew --version | head -1)"
    fi

    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        print_info "Apple Silicon (M1/M2/M3) detected"
    else
        print_info "Intel architecture detected"
    fi
}

# Update Homebrew
update_homebrew() {
    print_header "UPDATING HOMEBREW"

    brew update
    brew upgrade

    print_success "Homebrew updated"
}

# Install package with error handling
install_brew_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-25s${NC} ... " "$pkg"
    if brew install "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS $pkg"
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS $pkg"
        return 1
    fi
}

# Install cask with error handling
install_cask() {
    local cask=$1
    printf "Installing ${CYAN}%-25s${NC} ... " "$cask"
    if brew install --cask "$cask" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS cask:$cask"
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS cask:$cask"
        return 1
    fi
}

# Install Python package
install_pip_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-25s${NC} ... " "$pkg"
    if pip3 install --no-cache-dir "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED_PKGS="$INSTALLED_PKGS pip:$pkg"
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED_PKGS="$FAILED_PKGS pip:$pkg"
        return 1
    fi
}

# Minimal installation (~500MB)
install_minimal() {
    print_header "MINIMAL TOOLKIT (~500MB)"
    print_info "Essential debugging and analysis tools"
    echo ""

    # Core tools
    install_brew_pkg "git"
    install_brew_pkg "wget"
    install_brew_pkg "curl"

    # Debugging
    install_brew_pkg "gdb"
    install_brew_pkg "lldb"
    install_brew_pkg "binutils"

    # Python
    install_brew_pkg "python@3.11"
    ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3 2>/dev/null || true

    # Text tools
    install_brew_pkg "vim"
    install_brew_pkg "less"

    print_success "Minimal toolkit installation complete"
}

# Standard installation (~2-3GB)
install_standard() {
    print_header "STANDARD TOOLKIT (~2-3GB)"
    print_info "Complete bug bounty research environment"
    echo ""

    # Start with minimal
    install_minimal

    # Reverse engineering
    install_brew_pkg "radare2"
    install_brew_pkg "rizin"
    install_cask "ghidra" || print_warning "Ghidra cask failed"
    install_brew_pkg "binwalk"
    install_brew_pkg "sleuthkit"

    # Network analysis
    install_brew_pkg "nmap"
    install_brew_pkg "wireshark"
    install_brew_pkg "tcpdump"
    install_brew_pkg "netcat"
    install_brew_pkg "socat"

    # Web tools
    install_brew_pkg "nikto"
    install_brew_pkg "sqlmap"

    # Fuzzing
    install_brew_pkg "afl-fuzz"

    # Compression
    install_brew_pkg "p7zip"
    install_brew_pkg "xz"

    # Build tools
    install_brew_pkg "cmake"
    install_brew_pkg "make"

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

# Full installation (~5-7GB)
install_full() {
    print_header "FULL TOOLKIT (~5-7GB)"
    print_info "Everything for professional security research"
    echo ""

    # Start with standard
    install_standard

    # Additional RE tools
    install_cask "hopper-disassembler" || print_warning "Hopper not available"
    install_cask "ida-free" || print_warning "IDA Free not available"
    install_brew_pkg "capstone"
    install_brew_pkg "keystone"

    # Binary analysis
    install_brew_pkg "patchelf"
    install_brew_pkg "upx"

    # Hex editors
    install_cask "hex-fiend" || print_warning "Hex Fiend not available"

    # Network tools
    install_brew_pkg "mitmproxy"
    install_cask "burp-suite" || print_warning "Burp Suite not available"
    install_brew_pkg "masscan"
    install_brew_pkg "zmap"

    # Container tools
    install_cask "docker" || print_warning "Docker cask failed"

    # Scripting
    install_brew_pkg "node"
    install_brew_pkg "ruby"
    install_brew_pkg "go"
    install_brew_pkg "rust"

    # iOS tools (macOS-specific)
    install_brew_pkg "libimobiledevice"
    install_brew_pkg "ideviceinstaller"
    install_brew_pkg "ios-deploy"

    # Additional Python tools
    install_pip_pkg "scapy"
    install_pip_pkg "impacket"
    install_pip_pkg "z3-solver"
    install_pip_pkg "angr"
    install_pip_pkg "frida"
    install_pip_pkg "frida-tools"
    install_pip_pkg "objection"

    # Ruby gems
    gem install one_gadget 2>/dev/null || print_warning "one_gadget failed"

    print_success "Full toolkit installation complete"
}

# Install GEF
install_gef() {
    print_header "GDB ENHANCED FEATURES (GEF)"

    if ! command -v gdb >/dev/null 2>&1; then
        print_error "GDB not installed, skipping GEF"
        return 1
    fi

    print_info "Downloading GEF..."
    wget -q -O ~/.gdbinit-gef.py https://github.com/hugsy/gef/raw/main/gef.py
    echo "source ~/.gdbinit-gef.py" > ~/.gdbinit

    print_success "GEF installed successfully"
}

# Create verification script
create_verification() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > /usr/local/bin/check_macos_tools << 'VERIFY_EOF'
#!/bin/bash
echo "=== macOS Bug Bounty Toolkit Verification ==="
echo ""

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "%-25s: \033[0;32m✓ installed\033[0m\n" "$1"
        return 0
    else
        printf "%-25s: \033[0;31m✗ missing\033[0m\n" "$1"
        return 1
    fi
}

echo "Core Tools:"
check_tool brew
check_tool gdb
check_tool lldb
check_tool python3
echo ""

echo "Reverse Engineering:"
check_tool radare2
check_tool r2
check_tool rizin
check_tool ghidra
echo ""

echo "Network Tools:"
check_tool nmap
check_tool wireshark
check_tool tcpdump
check_tool socat
echo ""

echo "Python Packages:"
python3 -c "import pwn; print('pwntools                 : \033[0;32m✓\033[0m')" 2>/dev/null || echo "pwntools                 : \033[0;31m✗\033[0m"
python3 -c "import ropper; print('ropper                   : \033[0;32m✓\033[0m')" 2>/dev/null || echo "ropper                   : \033[0;31m✗\033[0m"
python3 -c "import capstone; print('capstone                 : \033[0;32m✓\033[0m')" 2>/dev/null || echo "capstone                 : \033[0;31m✗\033[0m"
echo ""

echo "Architecture         : $(uname -m)"
echo "macOS Version        : $(sw_vers -productVersion)"
echo "Homebrew Version     : $(brew --version | head -1)"
echo ""

if [ -f ~/.gdbinit-gef.py ]; then
    echo "GEF                  : \033[0;32m✓ installed\033[0m"
else
    echo "GEF                  : \033[0;31m✗ not installed\033[0m"
fi

echo ""
echo "=== Verification Complete ==="
VERIFY_EOF

    chmod +x /usr/local/bin/check_macos_tools
    print_success "Verification script created: check_macos_tools"
}

# Installation summary
print_summary() {
    print_header "INSTALLATION SUMMARY"

    echo -e "${GREEN}Successfully Installed:${NC}"
    echo "$INSTALLED_PKGS" | tr ' ' '\n' | grep -v "^$" | sort | uniq | head -20
    echo "  ... and more"
    echo ""

    if [ -n "$FAILED_PKGS" ]; then
        echo -e "${RED}Failed to Install:${NC}"
        for pkg in $FAILED_PKGS; do
            echo "  ✗ $pkg"
        done
        echo ""
    fi

    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Run verification: ${YELLOW}check_macos_tools${NC}"
    echo "  2. Test GDB: ${YELLOW}gdb --version${NC}"
    echo "  3. Test pwntools: ${YELLOW}python3 -c 'import pwn; print(pwn.__version__)'${NC}"
    echo ""

    print_info "macOS-specific notes:"
    echo "  • SIP may interfere with debugging system processes"
    echo "  • Use 'csrutil disable' in Recovery Mode to disable SIP (not recommended)"
    echo "  • Some tools require code signing for debugging"
    echo "  • Use 'codesign -s - -f --entitlements debug.entitlements <binary>'"
    echo ""

    print_success "macOS Bug Bounty Toolkit installation complete! 🎯🍎"
}

# Main menu
show_menu() {
    print_header "macOS BUG BOUNTY TOOLKIT (HOMEBREW)"
    echo "Professional Security Research for macOS"
    echo ""
    echo "Choose installation profile:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Minimal   (~500MB)   - Essential tools"
    echo -e "  ${BLUE}2)${NC} Standard  (~2-3GB)   - Complete toolkit ${YELLOW}[DEFAULT]${NC}"
    echo -e "  ${PURPLE}3)${NC} Full      (~5-7GB)   - Everything + GUI tools"
    echo -e "  ${CYAN}4)${NC} GEF Only  - Install GDB Enhanced Features"
    echo -e "  ${RED}5)${NC} Exit"
    echo ""
    printf "Select option [1-5] (default: 2): "
}

# Main execution
main() {
    check_homebrew

    case "$1" in
        --minimal)
            update_homebrew
            install_minimal
            install_gef
            create_verification
            print_summary
            ;;
        --standard|"")
            update_homebrew
            install_standard
            install_gef
            create_verification
            print_summary
            ;;
        --full)
            update_homebrew
            install_full
            install_gef
            create_verification
            print_summary
            ;;
        --gef-only)
            install_gef
            ;;
        --help|-h)
            echo "macOS Bug Bounty Toolkit Installer"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --minimal    Install minimal toolkit"
            echo "  --standard   Install standard toolkit [DEFAULT]"
            echo "  --full       Install full toolkit"
            echo "  --gef-only   Install GEF only"
            echo "  --help       Show this help"
            echo ""
            exit 0
            ;;
        *)
            show_menu
            read -r choice
            case ${choice:-2} in
                1)
                    update_homebrew
                    install_minimal
                    install_gef
                    create_verification
                    print_summary
                    ;;
                2)
                    update_homebrew
                    install_standard
                    install_gef
                    create_verification
                    print_summary
                    ;;
                3)
                    update_homebrew
                    install_full
                    install_gef
                    create_verification
                    print_summary
                    ;;
                4)
                    install_gef
                    ;;
                5)
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

main "$@"

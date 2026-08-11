#!/bin/bash
# Debian/Ubuntu/Kali Bug Bounty Toolkit Installer
# Professional security research tools for Debian-based Linux distributions
# Supports: Debian, Ubuntu, Kali Linux, Linux Mint, Pop!_OS, etc.
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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    print_success "Running with root privileges"
}

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        print_info "Detected: $NAME $VERSION"
    else
        print_warning "Cannot detect distribution, assuming Debian-based"
        DISTRO="debian"
    fi
}

# Update package repositories
update_repos() {
    print_header "UPDATING PACKAGE REPOSITORIES"

    apt-get update -y
    apt-get upgrade -y

    print_success "Repositories updated"
}

# Install package with error handling
install_pkg() {
    local pkg=$1
    printf "Installing ${CYAN}%-25s${NC} ... " "$pkg"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1; then
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

# Minimal installation (~300MB)
install_minimal() {
    print_header "MINIMAL TOOLKIT (~300MB)"
    print_info "Essential debugging and analysis tools"
    echo ""

    # Build essentials
    install_pkg "build-essential"
    install_pkg "git"
    install_pkg "curl"
    install_pkg "wget"

    # Core debugging
    install_pkg "gdb"
    install_pkg "gdb-multiarch"
    install_pkg "strace"
    install_pkg "ltrace"
    install_pkg "binutils"

    # Python
    install_pkg "python3"
    install_pkg "python3-pip"
    install_pkg "python3-dev"

    # Text tools
    install_pkg "vim"
    install_pkg "less"
    install_pkg "file"

    print_success "Minimal toolkit installation complete"
}

# Standard installation (~1-2GB)
install_standard() {
    print_header "STANDARD TOOLKIT (~1-2GB)"
    print_info "Complete bug bounty research environment"
    echo ""

    # Start with minimal
    install_minimal

    # Additional debugging
    install_pkg "valgrind"
    install_pkg "lldb"

    # Reverse engineering
    install_pkg "radare2"
    install_pkg "rizin" || print_warning "rizin not available"
    install_pkg "ghidra" || print_warning "ghidra not in repos"
    install_pkg "binwalk"
    install_pkg "foremost"
    install_pkg "exiftool"

    # Network analysis
    install_pkg "nmap"
    install_pkg "wireshark"
    install_pkg "tshark"
    install_pkg "tcpdump"
    install_pkg "netcat-openbsd"
    install_pkg "socat"
    install_pkg "dnsutils"
    install_pkg "traceroute"
    install_pkg "whois"
    install_pkg "iptables"

    # Web tools
    install_pkg "curl"
    install_pkg "wget"
    install_pkg "nikto" || print_warning "nikto not available"
    install_pkg "sqlmap" || print_warning "sqlmap not available"
    install_pkg "wfuzz" || print_warning "wfuzz not available"

    # Fuzzing
    install_pkg "afl++" || install_pkg "afl"
    install_pkg "honggfuzz" || print_warning "honggfuzz not available"

    # Exploitation tools
    install_pkg "metasploit-framework" || print_warning "metasploit not in standard repos"

    # Compression
    install_pkg "zip"
    install_pkg "unzip"
    install_pkg "p7zip-full"
    install_pkg "xz-utils"

    # Python security tools
    print_info "Installing Python security packages..."
    install_pip_pkg "pwntools"
    install_pip_pkg "ropper"
    install_pip_pkg "capstone"
    install_pip_pkg "keystone-engine"
    install_pip_pkg "unicorn"
    install_pip_pkg "z3-solver"
    install_pip_pkg "angr"
    install_pip_pkg "requests"
    install_pip_pkg "beautifulsoup4"
    install_pip_pkg "scapy"

    print_success "Standard toolkit installation complete"
}

# Full installation (~3-5GB)
install_full() {
    print_header "FULL TOOLKIT (~3-5GB)"
    print_info "Everything for professional security research"
    echo ""

    # Start with standard
    install_standard

    # Additional RE tools
    install_pkg "radare2-cutter" || print_warning "cutter not available"
    install_pkg "iaito" || print_warning "iaito not available"
    install_pkg "remnux" || print_warning "remnux not available"

    # Binary analysis
    install_pkg "checksec" || print_warning "checksec not available"
    install_pkg "patchelf"
    install_pkg "upx-ucl"
    install_pkg "lief" || print_warning "lief not available"

    # Hex editors
    install_pkg "hexedit"
    install_pkg "bless" || print_warning "bless not available"
    install_pkg "okteta" || print_warning "okteta not available"

    # Memory analysis
    install_pkg "volatility" || install_pkg "volatility3" || print_warning "volatility not available"

    # Wireless (if applicable)
    install_pkg "aircrack-ng" || print_warning "aircrack-ng not available"
    install_pkg "reaver" || print_warning "reaver not available"

    # Mobile tools
    install_pkg "apktool" || print_warning "apktool not available"
    install_pkg "jadx" || print_warning "jadx not available"

    # Container security
    install_pkg "docker.io"
    install_pkg "docker-compose"

    # Scripting languages
    install_pkg "nodejs"
    install_pkg "npm"
    install_pkg "ruby"
    install_pkg "ruby-dev"
    install_pkg "perl"
    install_pkg "php"

    # Additional Python tools
    install_pip_pkg "impacket"
    install_pip_pkg "frida"
    install_pip_pkg "frida-tools"
    install_pip_pkg "objection"
    install_pip_pkg "volatility3" || print_warning "volatility3 pip package failed"

    # Ruby gems
    gem install one_gadget 2>/dev/null || print_warning "one_gadget failed"
    gem install secureheaders 2>/dev/null || print_warning "secureheaders failed"

    print_success "Full toolkit installation complete"
}

# Kali-specific installations
install_kali_extras() {
    if [ "$DISTRO" = "kali" ]; then
        print_header "KALI LINUX EXTRAS"

        install_pkg "kali-tools-exploitation"
        install_pkg "kali-tools-web"
        install_pkg "kali-tools-reverse-engineering"
        install_pkg "kali-tools-fuzzing"

        print_success "Kali extras installed"
    fi
}

# Install GEF
install_gef() {
    print_header "GDB ENHANCED FEATURES (GEF)"

    print_info "Downloading GEF..."
    wget -q -O ~/.gdbinit-gef.py https://github.com/hugsy/gef/raw/main/gef.py
    echo "source ~/.gdbinit-gef.py" > ~/.gdbinit

    # Make available for all users
    cp ~/.gdbinit-gef.py /opt/gdbinit-gef.py 2>/dev/null || true

    print_success "GEF installed successfully"
}

# Create verification script
create_verification() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > /usr/local/bin/check_bugbounty_tools << 'VERIFY_EOF'
#!/bin/bash
echo "=== Bug Bounty Toolkit Verification ==="
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

echo "Core Debugging:"
check_tool gdb
check_tool gdb-multiarch
check_tool strace
check_tool ltrace
check_tool valgrind
check_tool lldb
echo ""

echo "Reverse Engineering:"
check_tool radare2
check_tool r2
check_tool ghidra
check_tool binwalk
echo ""

echo "Network Tools:"
check_tool nmap
check_tool wireshark
check_tool tcpdump
check_tool netcat
check_tool socat
echo ""

echo "Web Tools:"
check_tool nikto
check_tool sqlmap
check_tool wfuzz
echo ""

echo "Fuzzing:"
check_tool afl-fuzz
check_tool honggfuzz
echo ""

echo "Python Packages:"
python3 -c "import pwn; print('pwntools                 : \033[0;32m✓\033[0m')" 2>/dev/null || echo "pwntools                 : \033[0;31m✗\033[0m"
python3 -c "import ropper; print('ropper                   : \033[0;32m✓\033[0m')" 2>/dev/null || echo "ropper                   : \033[0;31m✗\033[0m"
python3 -c "import angr; print('angr                     : \033[0;32m✓\033[0m')" 2>/dev/null || echo "angr                     : \033[0;31m✗\033[0m"
python3 -c "import scapy; print('scapy                    : \033[0;32m✓\033[0m')" 2>/dev/null || echo "scapy                    : \033[0;31m✗\033[0m"
echo ""

if [ -f ~/.gdbinit-gef.py ] || [ -f /opt/gdbinit-gef.py ]; then
    echo "GEF                      : \033[0;32m✓ installed\033[0m"
else
    echo "GEF                      : \033[0;31m✗ not installed\033[0m"
fi

echo ""
echo "=== Verification Complete ==="
VERIFY_EOF

    chmod +x /usr/local/bin/check_bugbounty_tools
    print_success "Verification script created: /usr/local/bin/check_bugbounty_tools"
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
        print_warning "Some packages failed - this is normal on some distributions"
    fi

    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Run verification: ${YELLOW}check_bugbounty_tools${NC}"
    echo "  2. Test GDB: ${YELLOW}gdb --version${NC}"
    echo "  3. Test pwntools: ${YELLOW}python3 -c 'import pwn; print(pwn.__version__)'${NC}"
    echo "  4. Read docs: ${YELLOW}less DEBIAN_BUG_BOUNTY_GUIDE.md${NC}"
    echo ""
    print_success "Debian Bug Bounty Toolkit installation complete! 🎯"
}

# Main menu
show_menu() {
    print_header "DEBIAN/UBUNTU/KALI BUG BOUNTY TOOLKIT"
    echo "Professional Security Research Environment"
    echo ""
    echo "Choose installation profile:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Minimal   (~300MB)   - Essential debugging tools"
    echo -e "  ${BLUE}2)${NC} Standard  (~1-2GB)   - Complete toolkit ${YELLOW}[DEFAULT]${NC}"
    echo -e "  ${PURPLE}3)${NC} Full      (~3-5GB)   - Everything + extras"
    echo -e "  ${CYAN}4)${NC} Kali Extras - Kali-specific tool bundles"
    echo -e "  ${CYAN}5)${NC} GEF Only  - Install GDB Enhanced Features only"
    echo -e "  ${RED}6)${NC} Exit"
    echo ""
    printf "Select option [1-6] (default: 2): "
}

# Main execution
main() {
    check_root
    detect_distro

    case "$1" in
        --minimal)
            update_repos
            install_minimal
            install_gef
            create_verification
            print_summary
            ;;
        --standard|"")
            update_repos
            install_standard
            install_kali_extras
            install_gef
            create_verification
            print_summary
            ;;
        --full)
            update_repos
            install_full
            install_kali_extras
            install_gef
            create_verification
            print_summary
            ;;
        --kali-extras)
            install_kali_extras
            ;;
        --gef-only)
            install_gef
            ;;
        --help|-h)
            echo "Debian/Ubuntu/Kali Bug Bounty Toolkit Installer"
            echo ""
            echo "Usage: sudo $0 [option]"
            echo ""
            echo "Options:"
            echo "  --minimal       Install minimal toolkit"
            echo "  --standard      Install standard toolkit [DEFAULT]"
            echo "  --full          Install full toolkit"
            echo "  --kali-extras   Install Kali tool bundles (Kali only)"
            echo "  --gef-only      Install GEF only"
            echo "  --help          Show this help"
            echo ""
            exit 0
            ;;
        *)
            show_menu
            read -r choice
            case ${choice:-2} in
                1)
                    update_repos
                    install_minimal
                    install_gef
                    create_verification
                    print_summary
                    ;;
                2)
                    update_repos
                    install_standard
                    install_kali_extras
                    install_gef
                    create_verification
                    print_summary
                    ;;
                3)
                    update_repos
                    install_full
                    install_kali_extras
                    install_gef
                    create_verification
                    print_summary
                    ;;
                4)
                    install_kali_extras
                    ;;
                5)
                    install_gef
                    ;;
                6)
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

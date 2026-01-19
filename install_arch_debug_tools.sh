#!/bin/bash
# 🔧 Arch Linux Debugging Toolkit Quick Installer
# Purpose: Install essential debugging and security research tools
# Platform: Arch Linux / Arch Linux ARM
# Usage: bash install_arch_debug_tools.sh [--full|--minimal|--custom]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        print_error "Don't run this script as root!"
        print_info "The script will ask for sudo when needed"
        exit 1
    fi
}

check_arch() {
    if [ ! -f /etc/arch-release ]; then
        print_warning "This doesn't appear to be Arch Linux"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_package() {
    local package=$1
    if pacman -Qi "$package" &>/dev/null; then
        print_info "$package already installed"
    else
        echo -n "Installing $package... "
        if sudo pacman -S --noconfirm "$package" &>/dev/null; then
            print_success "$package installed"
        else
            print_warning "$package installation failed (might not be available)"
        fi
    fi
}

install_pip_package() {
    local package=$1
    echo -n "Installing Python package $package... "
    if pip install --user "$package" &>/dev/null 2>&1; then
        print_success "$package installed"
    else
        print_warning "$package installation failed"
    fi
}

install_gem_package() {
    local package=$1
    echo -n "Installing Ruby gem $package... "
    if gem install --user-install "$package" &>/dev/null 2>&1; then
        print_success "$package installed"
    else
        print_warning "$package installation failed"
    fi
}

# Installation profiles
install_minimal() {
    print_header "MINIMAL INSTALLATION"

    print_info "Core Debuggers"
    install_package "gdb"
    install_package "strace"
    install_package "valgrind"

    print_info "Basic Tools"
    install_package "binutils"
    install_package "base-devel"
    install_package "git"

    print_success "Minimal installation complete!"
}

install_standard() {
    print_header "STANDARD INSTALLATION"

    print_info "Core Debuggers"
    install_package "gdb"
    install_package "lldb"
    install_package "valgrind"
    install_package "strace"
    install_package "ltrace"

    print_info "Reverse Engineering"
    install_package "radare2"
    install_package "binutils"
    install_package "binwalk"
    install_package "checksec"

    print_info "Network Tools"
    install_package "wireshark-cli"
    install_package "tcpdump"
    install_package "nmap"
    install_package "socat"

    print_info "Build Tools"
    install_package "base-devel"
    install_package "cmake"
    install_package "git"

    print_info "Python Tools"
    install_package "python"
    install_package "python-pip"
    install_pip_package "pwntools"

    print_success "Standard installation complete!"
}

install_full() {
    print_header "FULL INSTALLATION"

    print_info "Core Debuggers"
    install_package "gdb"
    install_package "lldb"
    install_package "valgrind"
    install_package "strace"
    install_package "ltrace"

    print_info "Reverse Engineering"
    install_package "radare2"
    install_package "binutils"
    install_package "binwalk"
    install_package "checksec"
    install_package "ropgadget"
    install_package "patchelf"
    install_package "upx"

    print_info "Fuzzing Tools"
    install_package "afl++"
    install_package "honggfuzz"

    print_info "Network Tools"
    install_package "wireshark-qt"
    install_package "wireshark-cli"
    install_package "tcpdump"
    install_package "nmap"
    install_package "socat"
    install_package "gnu-netcat"

    print_info "Binary Analysis"
    install_package "capstone"
    install_package "keystone"
    install_package "unicorn"

    print_info "Performance Profiling"
    install_package "perf"
    install_package "heaptrack"

    print_info "Container Tools"
    install_package "docker"
    install_package "bubblewrap"

    print_info "Build Tools"
    install_package "base-devel"
    install_package "cmake"
    install_package "meson"
    install_package "git"
    install_package "gcc"
    install_package "clang"

    print_info "Utilities"
    install_package "hexedit"
    install_package "vim"
    install_package "file"
    install_package "diffutils"

    print_info "Python Environment"
    install_package "python"
    install_package "python-pip"
    install_pip_package "pwntools"
    install_pip_package "ropper"
    install_pip_package "capstone"
    install_pip_package "keystone-engine"
    install_pip_package "unicorn"
    install_pip_package "z3-solver"

    print_info "Ruby Environment"
    install_package "ruby"
    install_gem_package "one_gadget"

    print_success "Full installation complete!"
}

install_gef() {
    print_header "INSTALLING GDB ENHANCEMENTS"

    print_info "Installing GEF (GDB Enhanced Features)..."
    if bash -c "$(curl -fsSL https://gef.blah.cat/sh)" 2>/dev/null; then
        print_success "GEF installed successfully!"
        print_info "GEF will load automatically when you run gdb"
    else
        print_warning "GEF installation failed"
        print_info "You can install manually from: https://github.com/hugsy/gef"
    fi
}

install_peda() {
    print_header "INSTALLING PEDA"

    print_info "Installing PEDA (Python Exploit Development Assistance)..."
    if [ -d ~/peda ]; then
        print_warning "PEDA already installed at ~/peda"
    else
        git clone https://github.com/longld/peda.git ~/peda
        echo "source ~/peda/peda.py" >> ~/.gdbinit
        print_success "PEDA installed successfully!"
    fi
}

create_verification_script() {
    print_header "CREATING VERIFICATION SCRIPT"

    cat > ~/check_debug_tools.sh << 'VERIFY_EOF'
#!/bin/bash
# Debugging Toolkit Verification Script

echo "🔍 Checking Debugging Toolkit Installation"
echo "=========================================="
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

check_python_module() {
    if python3 -c "import $1" 2>/dev/null; then
        echo "✅ Python: $1"
        return 0
    else
        echo "❌ Python: $1"
        return 1
    fi
}

echo "Core Debuggers:"
check_cmd gdb
check_cmd lldb
check_cmd valgrind
check_cmd strace
echo

echo "Reverse Engineering:"
check_cmd radare2
check_cmd objdump
check_cmd nm
echo

echo "Network Tools:"
check_cmd wireshark
check_cmd tcpdump
check_cmd nmap
echo

echo "Binary Analysis:"
check_cmd binwalk
check_cmd checksec
echo

echo "Python Tools:"
check_python_module pwnlib
check_python_module capstone
check_python_module unicorn
echo

echo "Build Tools:"
check_cmd gcc
check_cmd make
check_cmd git
echo

echo "=========================================="
echo "✅ Verification complete!"
echo
echo "Run 'gdb' to test GDB with enhancements"
VERIFY_EOF

    chmod +x ~/check_debug_tools.sh
    print_success "Verification script created at ~/check_debug_tools.sh"
}

show_menu() {
    clear
    print_header "ARCH LINUX DEBUGGING TOOLKIT INSTALLER"
    echo
    echo "Choose installation profile:"
    echo
    echo "  1) Minimal    - Core debuggers only (gdb, strace, valgrind)"
    echo "  2) Standard   - Common tools (recommended)"
    echo "  3) Full       - Everything including fuzzing, RE tools"
    echo "  4) Custom     - Choose specific categories"
    echo "  5) GEF Only   - Install GDB Enhanced Features"
    echo "  6) Exit"
    echo
    read -p "Select option [1-6]: " choice

    case $choice in
        1) install_minimal ;;
        2) install_standard ;;
        3) install_full ;;
        4) install_custom ;;
        5) install_gef ;;
        6) exit 0 ;;
        *) print_error "Invalid option"; show_menu ;;
    esac
}

install_custom() {
    print_header "CUSTOM INSTALLATION"

    echo "Select categories to install (y/n):"
    echo

    read -p "Core Debuggers (gdb, valgrind, strace)? [Y/n]: " core
    read -p "Reverse Engineering (radare2, binutils)? [Y/n]: " re
    read -p "Fuzzing Tools (afl++, honggfuzz)? [y/N]: " fuzz
    read -p "Network Tools (wireshark, nmap, tcpdump)? [Y/n]: " net
    read -p "Python Tools (pwntools, capstone)? [Y/n]: " python
    read -p "Container Tools (docker, bubblewrap)? [y/N]: " container

    [[ "$core" =~ ^[Yy]$ ]] || [[ -z "$core" ]] && {
        print_info "Installing core debuggers..."
        install_package "gdb"
        install_package "lldb"
        install_package "valgrind"
        install_package "strace"
        install_package "ltrace"
    }

    [[ "$re" =~ ^[Yy]$ ]] || [[ -z "$re" ]] && {
        print_info "Installing reverse engineering tools..."
        install_package "radare2"
        install_package "binutils"
        install_package "binwalk"
        install_package "checksec"
    }

    [[ "$fuzz" =~ ^[Yy]$ ]] && {
        print_info "Installing fuzzing tools..."
        install_package "afl++"
        install_package "honggfuzz"
    }

    [[ "$net" =~ ^[Yy]$ ]] || [[ -z "$net" ]] && {
        print_info "Installing network tools..."
        install_package "wireshark-cli"
        install_package "tcpdump"
        install_package "nmap"
        install_package "socat"
    }

    [[ "$python" =~ ^[Yy]$ ]] || [[ -z "$python" ]] && {
        print_info "Installing Python tools..."
        install_package "python"
        install_package "python-pip"
        install_pip_package "pwntools"
        install_pip_package "ropper"
        install_pip_package "capstone"
    }

    [[ "$container" =~ ^[Yy]$ ]] && {
        print_info "Installing container tools..."
        install_package "docker"
        install_package "bubblewrap"
    }

    print_success "Custom installation complete!"
}

post_install() {
    print_header "POST-INSTALLATION"

    echo
    read -p "Install GDB enhancements (GEF)? [Y/n]: " gef
    [[ "$gef" =~ ^[Yy]$ ]] || [[ -z "$gef" ]] && install_gef

    echo
    read -p "Create verification script? [Y/n]: " verify
    [[ "$verify" =~ ^[Yy]$ ]] || [[ -z "$verify" ]] && create_verification_script

    print_header "INSTALLATION COMPLETE!"
    echo
    print_success "Debugging toolkit installed successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Run ~/check_debug_tools.sh to verify installation"
    echo "  2. Start using: gdb, radare2, strace, etc."
    echo "  3. Read documentation: less ARCH_LINUX_DEBUGGING_TOOLKIT.md"
    echo
    print_info "For bug bounty research, also check:"
    echo "  - bug-bounty-toolkit/ directory"
    echo "  - redteam-toolkit/ directory"
    echo
}

# Main execution
main() {
    check_root
    check_arch

    # Update package database
    print_info "Updating package database..."
    sudo pacman -Sy

    # Show menu if no arguments
    if [ $# -eq 0 ]; then
        show_menu
        post_install
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
                echo "  --minimal   Install core debuggers only"
                echo "  --standard  Install common tools (recommended)"
                echo "  --full      Install everything"
                echo "  --gef-only  Install GDB Enhanced Features only"
                echo "  --help      Show this help"
                echo
                echo "No arguments: Show interactive menu"
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    fi
}

main "$@"

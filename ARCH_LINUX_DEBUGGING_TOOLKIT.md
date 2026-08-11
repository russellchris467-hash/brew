# 🐧 Arch Linux Debugging & Security Research Toolkit
## Complete Installation Guide for Security Researchers

**Version:** 1.0.0
**Platform:** Arch Linux / Arch Linux ARM
**Purpose:** 🔧 Professional debugging, reverse engineering, and security research
**Status:** ✅ For authorized research and development

---

## 📋 Table of Contents

1. [System Preparation](#system-preparation)
2. [Core Debugging Tools](#core-debugging-tools)
3. [Reverse Engineering](#reverse-engineering)
4. [Dynamic Analysis](#dynamic-analysis)
5. [Fuzzing & Testing](#fuzzing--testing)
6. [Network Analysis](#network-analysis)
7. [Binary Analysis](#binary-analysis)
8. [Kernel Debugging](#kernel-debugging)
9. [Container Security](#container-security)
10. [Performance Profiling](#performance-profiling)
11. [Python Tools](#python-tools)
12. [Ruby Tools](#ruby-tools)
13. [Verification](#verification)

---

## 🚀 System Preparation

### Update System

```bash
# Update package database
sudo pacman -Syu

# Update keyring if needed
sudo pacman -S archlinux-keyring

# Clear package cache (optional)
sudo pacman -Sc
```

### Enable Multilib (64-bit systems)

```bash
# Edit pacman.conf
sudo nano /etc/pacman.conf

# Uncomment these lines:
# [multilib]
# Include = /etc/pacman.d/mirrorlist

# Update database
sudo pacman -Sy
```

### Install Base Development Tools

```bash
# Base development group
sudo pacman -S base-devel

# Git and version control
sudo pacman -S git mercurial subversion

# Build tools
sudo pacman -S cmake meson ninja autoconf automake

# Compilers
sudo pacman -S gcc clang llvm
```

---

## 🔧 Core Debugging Tools

### GDB - GNU Debugger

```bash
# Install GDB
sudo pacman -S gdb

# Install GDB enhancements
sudo pacman -S gdb-common

# Install GEF (GDB Enhanced Features)
bash -c "$(curl -fsSL https://gef.blah.cat/sh)"

# Or install PEDA (Python Exploit Development Assistance)
git clone https://github.com/longld/peda.git ~/peda
echo "source ~/peda/peda.py" >> ~/.gdbinit

# Or install pwndbg
git clone https://github.com/pwndbg/pwndbg
cd pwndbg
./setup.sh
```

### LLDB - LLVM Debugger

```bash
# Install LLDB
sudo pacman -S lldb

# Install Python bindings
sudo pacman -S python-lldb
```

### Valgrind - Memory Debugger

```bash
# Install Valgrind
sudo pacman -S valgrind

# Valgrind tools available:
# - memcheck (memory errors)
# - cachegrind (cache profiling)
# - callgrind (call graph)
# - helgrind (threading bugs)
# - massif (heap profiler)
```

### Strace - System Call Tracer

```bash
# Install strace
sudo pacman -S strace

# Install ltrace (library call tracer)
sudo pacman -S ltrace
```

---

## 🔍 Reverse Engineering

### Ghidra - NSA's Reverse Engineering Tool

```bash
# Install Ghidra from AUR
yay -S ghidra

# Or manually:
# 1. Install JDK
sudo pacman -S jdk-openjdk

# 2. Download Ghidra
wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20231222.zip

# 3. Extract and run
unzip ghidra_*.zip
cd ghidra_*
./ghidraRun
```

### Radare2 - Advanced Reverse Engineering

```bash
# Install radare2
sudo pacman -S radare2

# Install Cutter (GUI for radare2)
sudo pacman -S cutter

# Install r2ghidra (Ghidra decompiler for radare2)
r2pm -ci r2ghidra
```

### Binary Ninja (Commercial, but has demo)

```bash
# Install from AUR
yay -S binaryninja-demo

# Or download manually from:
# https://binary.ninja/demo/
```

### IDA Free (Freeware version)

```bash
# Download IDA Free manually
# https://hex-rays.com/ida-free/

# Install dependencies
sudo pacman -S qt5-base
```

### Hopper Disassembler

```bash
# Install from AUR
yay -S hopper-v4
```

### Objdump & Binutils

```bash
# Usually already installed, but ensure you have:
sudo pacman -S binutils

# Tools included:
# - objdump (disassembler)
# - nm (symbol viewer)
# - strings (string extractor)
# - readelf (ELF analyzer)
# - objcopy (object file converter)
```

---

## 🎯 Dynamic Analysis

### Frida - Dynamic Instrumentation

```bash
# Install Python
sudo pacman -S python python-pip

# Install Frida
sudo pip install frida-tools

# Install Frida server for Android/iOS (if needed)
# Download from: https://github.com/frida/frida/releases
```

### Pin - Intel's Dynamic Instrumentation

```bash
# Download Pin
wget https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.28-98749-g6643ecee5-gcc-linux.tar.gz

# Extract
tar xzf pin-*.tar.gz

# Add to PATH
echo 'export PATH=$PATH:~/pin' >> ~/.bashrc
source ~/.bashrc
```

### DynamoRIO

```bash
# Install from AUR
yay -S dynamorio

# Or build from source:
git clone https://github.com/DynamoRIO/dynamorio.git
cd dynamorio
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

---

## 🎲 Fuzzing & Testing

### AFL++ (American Fuzzy Lop)

```bash
# Install AFL++
sudo pacman -S afl++

# Or build latest from source:
git clone https://github.com/AFLplusplus/AFLplusplus
cd AFLplusplus
make
sudo make install
```

### LibFuzzer

```bash
# Part of LLVM/Clang
sudo pacman -S clang

# LibFuzzer is included with clang
```

### Honggfuzz

```bash
# Install honggfuzz
sudo pacman -S honggfuzz

# Or from source:
git clone https://github.com/google/honggfuzz
cd honggfuzz
make
sudo make install
```

### Syzkaller (Kernel Fuzzer)

```bash
# Install Go
sudo pacman -S go

# Clone and build
git clone https://github.com/google/syzkaller
cd syzkaller
make
```

### Radamsa (Fuzzer)

```bash
# Install radamsa
yay -S radamsa

# Or build from source:
git clone https://gitlab.com/akihe/radamsa.git
cd radamsa
make
sudo make install
```

---

## 🌐 Network Analysis

### Wireshark

```bash
# Install Wireshark
sudo pacman -S wireshark-qt

# Add user to wireshark group
sudo usermod -aG wireshark $USER

# Install tshark (CLI version)
sudo pacman -S wireshark-cli
```

### Tcpdump

```bash
# Install tcpdump
sudo pacman -S tcpdump

# Install tcpreplay (replay packets)
sudo pacman -S tcpreplay
```

### Nmap - Network Scanner

```bash
# Install nmap
sudo pacman -S nmap

# Install Zenmap (GUI)
yay -S zenmap
```

### Netcat

```bash
# Install GNU netcat
sudo pacman -S gnu-netcat

# Or OpenBSD netcat
sudo pacman -S openbsd-netcat
```

### Socat - Advanced Socket Tool

```bash
# Install socat
sudo pacman -S socat
```

### Burp Suite (Web Security)

```bash
# Install Burp Suite Community
yay -S burpsuite

# Or download manually:
# https://portswigger.net/burp/communitydownload
```

### OWASP ZAP

```bash
# Install ZAP
sudo pacman -S zaproxy
```

---

## 📊 Binary Analysis

### Binwalk - Firmware Analysis

```bash
# Install binwalk
sudo pacman -S binwalk

# Install extraction dependencies
sudo pacman -S p7zip unrar unzip lhasa cabextract cramfs squashfs-tools
```

### Checksec

```bash
# Install checksec
sudo pacman -S checksec

# Or install pwntools which includes checksec
pip install pwntools
```

### ROPgadget

```bash
# Install ROPgadget
pip install ropgadget

# Or from pacman
sudo pacman -S ropgadget
```

### One_Gadget

```bash
# Install Ruby
sudo pacman -S ruby

# Install one_gadget
gem install one_gadget
```

### Patchelf

```bash
# Install patchelf
sudo pacman -S patchelf
```

### UPX (Packer/Unpacker)

```bash
# Install UPX
sudo pacman -S upx
```

---

## 🔬 Kernel Debugging

### Kernel Debug Symbols

```bash
# Install debug kernel
yay -S linux-debug

# Install kernel headers
sudo pacman -S linux-headers
```

### KGDB Setup

```bash
# Enable kernel debugging in GRUB
sudo nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX:
# kgdboc=ttyS0,115200 kgdbwait

# Update GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Crash Utility

```bash
# Install crash
sudo pacman -S crash

# For analyzing kernel crash dumps
```

### SystemTap

```bash
# Install SystemTap
sudo pacman -S systemtap

# Install kernel headers
sudo pacman -S linux-headers
```

### BPF Tools

```bash
# Install BPF Compiler Collection
sudo pacman -S bpf

# Install bpftrace
sudo pacman -S bpftrace

# Install libbpf
sudo pacman -S libbpf
```

---

## 🐳 Container Security

### Docker Debugging Tools

```bash
# Install Docker
sudo pacman -S docker docker-compose

# Start Docker service
sudo systemctl enable --now docker

# Add user to docker group
sudo usermod -aG docker $USER

# Install dive (Docker image analysis)
yay -S dive

# Install trivy (vulnerability scanner)
yay -S trivy
```

### Podman

```bash
# Install Podman
sudo pacman -S podman podman-compose

# Install buildah
sudo pacman -S buildah

# Install skopeo
sudo pacman -S skopeo
```

### Bubblewrap (Sandboxing)

```bash
# Install bubblewrap
sudo pacman -S bubblewrap
```

---

## ⚡ Performance Profiling

### Perf

```bash
# Install perf
sudo pacman -S perf

# Install perf visualization
sudo pacman -S hotspot
```

### Flamegraph

```bash
# Clone flamegraph
git clone https://github.com/brendangregg/FlameGraph
cd FlameGraph

# Add to PATH
echo 'export PATH=$PATH:~/FlameGraph' >> ~/.bashrc
```

### Heaptrack

```bash
# Install heaptrack
sudo pacman -S heaptrack
```

### Massif Visualizer

```bash
# Install massif-visualizer
sudo pacman -S massif-visualizer
```

---

## 🐍 Python Security Tools

### Pwntools

```bash
# Install pwntools
pip install pwntools

# Or with all extras
pip install pwntools[all]
```

### Ropper

```bash
# Install ropper
pip install ropper
```

### Capstone Disassembler

```bash
# Install capstone
sudo pacman -S capstone

# Python bindings
pip install capstone
```

### Keystone Assembler

```bash
# Install keystone
sudo pacman -S keystone

# Python bindings
pip install keystone-engine
```

### Unicorn Emulator

```bash
# Install unicorn
sudo pacman -S unicorn

# Python bindings
pip install unicorn
```

### Angr - Binary Analysis

```bash
# Install angr
pip install angr

# Install angr-management (GUI)
pip install angr-management
```

### Z3 Theorem Prover

```bash
# Install z3
sudo pacman -S z3

# Python bindings
pip install z3-solver
```

---

## 💎 Ruby Security Tools

### Metasploit Framework

```bash
# Install from AUR
yay -S metasploit

# Or install via Ruby
gem install metasploit-framework

# Initialize database
msfdb init
```

### Ronin

```bash
# Install ronin
gem install ronin ronin-exploits ronin-payloads ronin-web
```

---

## 🔐 Additional Security Tools

### SQLMap

```bash
# Install sqlmap
sudo pacman -S sqlmap
```

### John the Ripper

```bash
# Install john
sudo pacman -S john
```

### Hashcat

```bash
# Install hashcat
sudo pacman -S hashcat

# Install OpenCL (for GPU acceleration)
sudo pacman -S ocl-icd opencl-headers
```

### Aircrack-ng

```bash
# Install aircrack-ng
sudo pacman -S aircrack-ng
```

### Hydra

```bash
# Install hydra
sudo pacman -S hydra
```

---

## 🛠️ Utility Tools

### Hexdump & Hex Editors

```bash
# Install hexdump (usually included)
sudo pacman -S util-linux

# Install hex editors
sudo pacman -S hexedit ghex bless

# Install xxd (comes with vim)
sudo pacman -S vim
```

### File Command

```bash
# Install file
sudo pacman -S file
```

### Diff Tools

```bash
# Install diff tools
sudo pacman -S diffutils colordiff meld
```

### Compression Tools

```bash
# Install compression tools
sudo pacman -S p7zip unzip unrar zip gzip bzip2 xz
```

---

## ✅ Verification & Testing

### Verify Installation

```bash
#!/bin/bash
# Save as check_tools.sh and run: bash check_tools.sh

echo "🔍 Checking Debugging Toolkit Installation"
echo "=========================================="
echo

# Core debuggers
echo "Core Debuggers:"
command -v gdb >/dev/null && echo "✅ GDB" || echo "❌ GDB"
command -v lldb >/dev/null && echo "✅ LLDB" || echo "❌ LLDB"
command -v valgrind >/dev/null && echo "✅ Valgrind" || echo "❌ Valgrind"
command -v strace >/dev/null && echo "✅ Strace" || echo "❌ Strace"
echo

# Reverse engineering
echo "Reverse Engineering:"
command -v radare2 >/dev/null && echo "✅ Radare2" || echo "❌ Radare2"
command -v ghidra >/dev/null && echo "✅ Ghidra" || echo "❌ Ghidra"
command -v objdump >/dev/null && echo "✅ Objdump" || echo "❌ Objdump"
echo

# Fuzzing
echo "Fuzzing Tools:"
command -v afl-fuzz >/dev/null && echo "✅ AFL++" || echo "❌ AFL++"
command -v honggfuzz >/dev/null && echo "✅ Honggfuzz" || echo "❌ Honggfuzz"
echo

# Network analysis
echo "Network Analysis:"
command -v wireshark >/dev/null && echo "✅ Wireshark" || echo "❌ Wireshark"
command -v tcpdump >/dev/null && echo "✅ Tcpdump" || echo "❌ Tcpdump"
command -v nmap >/dev/null && echo "✅ Nmap" || echo "❌ Nmap"
echo

# Binary analysis
echo "Binary Analysis:"
command -v binwalk >/dev/null && echo "✅ Binwalk" || echo "❌ Binwalk"
command -v checksec >/dev/null && echo "✅ Checksec" || echo "❌ Checksec"
echo

# Python tools
echo "Python Tools:"
python3 -c "import pwnlib" 2>/dev/null && echo "✅ Pwntools" || echo "❌ Pwntools"
python3 -c "import capstone" 2>/dev/null && echo "✅ Capstone" || echo "❌ Capstone"
python3 -c "import unicorn" 2>/dev/null && echo "✅ Unicorn" || echo "❌ Unicorn"
echo

echo "=========================================="
echo "✅ Toolkit check complete!"
```

### Test GDB with GEF

```bash
# Create test program
cat > test.c << 'EOF'
#include <stdio.h>
int main() {
    char buffer[64];
    printf("Enter text: ");
    gets(buffer);  // Vulnerable!
    printf("You entered: %s\n", buffer);
    return 0;
}
EOF

# Compile with debug symbols
gcc -g -fno-stack-protector -z execstack test.c -o test

# Debug with GDB
gdb ./test

# GEF should load automatically
# Try commands: checksec, vmmap, pattern create 100
```

### Test Radare2

```bash
# Analyze a binary
r2 /bin/ls

# Auto analysis
aa

# List functions
afl

# Disassemble main
pdf @main

# Exit
q
```

---

## 📚 Quick Reference Commands

### GDB Essentials

```bash
# Start debugging
gdb ./program

# With arguments
gdb --args ./program arg1 arg2

# Attach to running process
gdb -p <PID>

# Common commands
(gdb) run                    # Start program
(gdb) break main             # Set breakpoint
(gdb) continue               # Continue execution
(gdb) step                   # Step into
(gdb) next                   # Step over
(gdb) print variable         # Print variable
(gdb) backtrace              # Show stack trace
(gdb) info registers         # Show registers
(gdb) x/10x $rsp             # Examine memory
```

### Strace Examples

```bash
# Trace system calls
strace ./program

# Trace specific syscall
strace -e open ./program

# Trace file operations
strace -e trace=file ./program

# Trace network operations
strace -e trace=network ./program

# Count syscalls
strace -c ./program

# Trace child processes
strace -f ./program
```

### Valgrind Examples

```bash
# Memory leak check
valgrind --leak-check=full ./program

# Cache profiling
valgrind --tool=cachegrind ./program

# Call graph
valgrind --tool=callgrind ./program

# Thread debugging
valgrind --tool=helgrind ./threaded_program

# Heap profiling
valgrind --tool=massif ./program
```

---

## 🎯 Use Cases

### 1. Debugging Crashes

```bash
# Compile with debug symbols
gcc -g program.c -o program

# Run with gdb
gdb ./program
(gdb) run

# When crash occurs
(gdb) backtrace
(gdb) info registers
(gdb) x/20x $rsp
```

### 2. Finding Memory Leaks

```bash
# Run valgrind
valgrind --leak-check=full --show-leak-kinds=all ./program

# Check output for:
# - definitely lost
# - indirectly lost
# - possibly lost
```

### 3. Reverse Engineering Binary

```bash
# Check binary properties
file binary
checksec --file=binary

# Disassemble with radare2
r2 binary
aa
afl
pdf @main

# Or use Ghidra GUI
ghidra
```

### 4. Fuzzing for Bugs

```bash
# Compile with AFL instrumentation
afl-gcc program.c -o program

# Create input directory
mkdir inputs
echo "test" > inputs/seed1

# Fuzz
afl-fuzz -i inputs -o outputs ./program @@
```

### 5. Network Protocol Analysis

```bash
# Capture packets
sudo tcpdump -i eth0 -w capture.pcap

# Analyze in Wireshark
wireshark capture.pcap

# Or with tshark
tshark -r capture.pcap
```

---

## 🔒 Security Considerations

### Running with Privileges

```bash
# Some tools need root
sudo gdb ./program
sudo strace ./program
sudo tcpdump -i eth0

# Use sudo carefully!
```

### Kernel Debugging Safety

```bash
# NEVER debug production kernel
# Use VM or test system
# Have backups before kernel debugging
```

### Container Isolation

```bash
# Run risky debugging in containers
docker run -it --rm archlinux bash
# Install tools and debug inside container
```

---

## 📖 Documentation & Resources

### Man Pages

```bash
# Install man pages
sudo pacman -S man-db man-pages

# Read documentation
man gdb
man strace
man valgrind
```

### Online Resources

- **GDB:** https://sourceware.org/gdb/documentation/
- **Radare2:** https://book.rada.re/
- **Ghidra:** https://ghidra-sre.org/
- **AFL++:** https://aflplus.plus/
- **Pwntools:** https://docs.pwntools.com/

---

## 🎉 Complete Installation Script

```bash
#!/bin/bash
# Complete Arch Linux debugging toolkit installer
# Run as: bash install_debug_toolkit.sh

echo "🔧 Installing Arch Linux Debugging Toolkit"
echo "==========================================="

# Update system
echo "📦 Updating system..."
sudo pacman -Syu --noconfirm

# Core debugging
echo "🔍 Installing core debuggers..."
sudo pacman -S --noconfirm gdb lldb valgrind strace ltrace

# Reverse engineering
echo "🔬 Installing reverse engineering tools..."
sudo pacman -S --noconfirm radare2 binutils

# Fuzzing
echo "🎲 Installing fuzzing tools..."
sudo pacman -S --noconfirm afl++

# Network analysis
echo "🌐 Installing network tools..."
sudo pacman -S --noconfirm wireshark-cli tcpdump nmap socat

# Binary analysis
echo "📊 Installing binary analysis tools..."
sudo pacman -S --noconfirm binwalk checksec

# Python tools
echo "🐍 Installing Python tools..."
pip install pwntools ropper capstone keystone-engine unicorn

# Build tools
echo "🛠️  Installing build tools..."
sudo pacman -S --noconfirm base-devel cmake

# Additional utilities
echo "⚙️  Installing utilities..."
sudo pacman -S --noconfirm hexedit vim git

echo
echo "✅ Installation complete!"
echo
echo "Next steps:"
echo "  1. Install GEF: bash -c '\$(curl -fsSL https://gef.blah.cat/sh)'"
echo "  2. Verify: Run check_tools.sh"
echo "  3. Start debugging!"
```

---

**Version:** 1.0.0
**Last Updated:** 2026-01-19
**Platform:** Arch Linux / Arch Linux ARM
**Purpose:** 🔧 Professional debugging and security research
**Status:** ✅ Ready to use!

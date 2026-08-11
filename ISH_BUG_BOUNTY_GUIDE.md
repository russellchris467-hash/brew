# iSH Bug Bounty Toolkit Guide

> Professional security research and bug bounty tools for iSH on iOS
> Optimized for Alpine Linux in a mobile environment

## Table of Contents

- [What is iSH?](#what-is-ish)
- [Quick Start](#quick-start)
- [Installation Profiles](#installation-profiles)
- [Tool Categories](#tool-categories)
- [Usage Examples](#usage-examples)
- [iSH-Specific Considerations](#ish-specific-considerations)
- [Bug Bounty Workflow](#bug-bounty-workflow)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## What is iSH?

**iSH** is a Linux shell environment for iOS that runs Alpine Linux using x86 emulation. It allows you to run Linux command-line tools directly on your iPhone or iPad.

### Key Features
- ✅ Full Alpine Linux environment
- ✅ APK package manager
- ✅ Python, Ruby, Perl support
- ✅ Networking capabilities
- ✅ File system access
- ✅ SSH client/server

### Limitations
- ⚠️ x86 emulation on ARM (slower performance)
- ⚠️ iOS sandbox restrictions
- ⚠️ Limited memory (device dependent)
- ⚠️ No kernel modules
- ⚠️ Some syscalls unavailable
- ⚠️ musl libc instead of glibc

## Quick Start

### 1. Install iSH from App Store
Download iSH from the iOS App Store (free)

### 2. Update Package Repository
```bash
apk update
apk upgrade
```

### 3. Run the Installer
```bash
# Download the installer
wget https://raw.githubusercontent.com/yourrepo/brew/claude/sandbox-escape-protocol-45fM0/ish_bugbounty_toolkit.sh

# Make executable
chmod +x ish_bugbounty_toolkit.sh

# Run installer (standard profile recommended)
./ish_bugbounty_toolkit.sh --standard
```

### 4. Verify Installation
```bash
~/check_ish_tools.sh
```

## Installation Profiles

### Minimal (~50-100MB)
**Essential debugging tools only**

**Includes:**
- Build essentials (gcc, make, git)
- GDB debugger
- strace/ltrace
- binutils (objdump, readelf, strings)
- Python 3 + pip
- Basic text tools (vim, less, grep)

**Best for:**
- Limited storage devices
- Quick debugging sessions
- Learning fundamentals

**Installation:**
```bash
./ish_bugbounty_toolkit.sh --minimal
```

### Standard (~200-500MB) **[RECOMMENDED]**
**Complete bug bounty research toolkit**

**Includes everything in Minimal plus:**
- Network analysis (nmap, tcpdump, netcat, socat)
- Reverse engineering (radare2, objdump)
- Python security tools (pwntools, ropper, capstone)
- Archive tools (tar, gzip, zip, xz)
- Additional debugging (valgrind, hexdump)
- GDB Enhanced Features (GEF)

**Best for:**
- Bug bounty research
- CTF competitions
- Security auditing
- General reverse engineering

**Installation:**
```bash
./ish_bugbounty_toolkit.sh --standard
# or simply:
./ish_bugbounty_toolkit.sh
```

### Full (~500MB-1GB)
**Everything including advanced tools**

**Includes everything in Standard plus:**
- LLDB debugger
- Advanced network tools (wireshark/tshark, bind-tools)
- Web tools (curl-dev, openssl-dev)
- Development tools (cmake, clang)
- Multiple scripting languages (bash, perl, ruby)
- Advanced Python packages (scapy, requests, beautifulsoup4)
- Binary manipulation (upx, patchelf)

**Best for:**
- Professional security researchers
- Complex vulnerability analysis
- Devices with ample storage

**Installation:**
```bash
./ish_bugbounty_toolkit.sh --full
```

### GEF Only
**Just install GDB Enhanced Features**

```bash
./ish_bugbounty_toolkit.sh --gef-only
```

## Tool Categories

### 1. Core Debugging Tools

#### GDB (GNU Debugger)
The standard Linux debugger for analyzing binaries.

```bash
# Debug a program
gdb ./vulnerable_binary

# Common commands
(gdb) run                    # Execute program
(gdb) break main             # Set breakpoint
(gdb) info registers         # Show registers
(gdb) backtrace             # Show call stack
(gdb) disassemble main      # Disassemble function
(gdb) x/20x $esp            # Examine memory
```

#### GEF (GDB Enhanced Features)
Modern GDB enhancement with extra commands and visualization.

```bash
gdb ./binary
# GEF loads automatically

# GEF-specific commands
gef> vmmap              # Show memory mappings
gef> checksec           # Check binary protections
gef> pattern create 200 # Create cyclic pattern
gef> pattern offset 0x61616161  # Find pattern offset
gef> heap chunks        # Show heap chunks
gef> rop                # Find ROP gadgets
```

#### Strace
Trace system calls and signals.

```bash
# Basic usage
strace ./program

# Follow forks
strace -f ./program

# Trace specific syscalls
strace -e open,read,write ./program

# Save to file
strace -o trace.log ./program

# Attach to running process
strace -p <pid>
```

#### Ltrace
Trace library calls.

```bash
# Trace library calls
ltrace ./program

# Show time information
ltrace -t ./program

# Count calls
ltrace -c ./program
```

### 2. Reverse Engineering

#### Radare2
Powerful reverse engineering framework.

```bash
# Open binary
r2 ./binary

# Analysis
[0x00000000]> aa          # Analyze all
[0x00000000]> aaa         # Deep analysis
[0x00000000]> afl         # List functions

# Disassembly
[0x00000000]> pdf @main   # Disassemble main
[0x00000000]> s main      # Seek to main
[0x00000000]> VV          # Visual graph mode

# Search
[0x00000000]> / password  # Search string
[0x00000000]> /R pop rdi  # Search instructions

# Information
[0x00000000]> i           # Binary info
[0x00000000]> iz          # List strings
[0x00000000]> ii          # List imports
```

#### Binutils Suite

**objdump** - Object file analysis
```bash
# Disassemble
objdump -d binary

# Disassemble specific section
objdump -d -j .text binary

# Show all headers
objdump -x binary

# Show symbols
objdump -t binary

# Intel syntax
objdump -M intel -d binary
```

**readelf** - ELF file analysis
```bash
# ELF header
readelf -h binary

# Program headers
readelf -l binary

# Section headers
readelf -S binary

# Symbol table
readelf -s binary

# Dynamic section
readelf -d binary

# Relocations
readelf -r binary
```

**strings** - Extract printable strings
```bash
# Basic usage
strings binary

# Minimum length 10
strings -n 10 binary

# Show file offsets
strings -t x binary

# Scan entire file
strings -a binary
```

### 3. Network Analysis

#### Nmap
Network scanner and port scanner.

```bash
# Basic scan
nmap target.com

# Service version detection
nmap -sV target.com

# All ports
nmap -p- target.com

# Aggressive scan
nmap -A target.com

# Scan multiple hosts
nmap 192.168.1.0/24

# OS detection
nmap -O target.com

# Script scan
nmap --script vuln target.com
```

#### Tcpdump
Packet capture and analysis.

```bash
# Capture on all interfaces
tcpdump -i any

# Capture HTTP traffic
tcpdump -i any port 80

# Save to file
tcpdump -w capture.pcap

# Read from file
tcpdump -r capture.pcap

# Show ASCII
tcpdump -A port 80

# Specific host
tcpdump host 192.168.1.100
```

#### Netcat
Network swiss army knife.

```bash
# Listen on port
nc -l -p 4444

# Connect to port
nc target.com 80

# Banner grabbing
echo "" | nc target.com 22

# File transfer (receiver)
nc -l -p 4444 > file.txt

# File transfer (sender)
nc target.com 4444 < file.txt

# Port scanning
nc -zv target.com 20-100
```

### 4. Python Security Tools

#### Pwntools
CTF and exploit development framework.

```python
#!/usr/bin/env python3
from pwn import *

# Connect to service
r = remote('target.com', 1337)

# Or local process
r = process('./vulnerable')

# Context settings
context.arch = 'amd64'
context.os = 'linux'

# Build payload
payload = fit({
    0: b'AAAA',
    64: p64(0xdeadbeef)
})

# Send payload
r.sendline(payload)

# Receive data
r.recvuntil(b'Enter input:')
data = r.recvline()

# Interactive shell
r.interactive()

# Cyclic patterns
pattern = cyclic(200)
offset = cyclic_find(0x61616161)

# ELF analysis
elf = ELF('./binary')
print(hex(elf.symbols['main']))
print(hex(elf.got['puts']))

# ROP
rop = ROP(elf)
rop.call('system', ['/bin/sh'])
print(rop.dump())
```

#### Ropper
ROP gadget finder.

```python
#!/usr/bin/env python3
from ropper import RopperService

# Initialize
rs = RopperService()
rs.addFile('binary')
rs.loadGadgetsFor()

# Search for gadgets
gadgets = rs.searchPopPopRet()
for gadget in gadgets:
    print(gadget)

# Specific search
gadgets = rs.search(search='pop rdi')
```

**Command line:**
```bash
# List all gadgets
ropper --file binary

# Search specific
ropper --file binary --search "pop rdi"

# ROPchain
ropper --file binary --chain "execve"

# Multiple files
ropper --file binary --file libc.so.6
```

#### Capstone
Disassembly framework.

```python
#!/usr/bin/env python3
from capstone import *

# Initialize for x86-64
md = Cs(CS_ARCH_X86, CS_MODE_64)

# Disassemble
code = b"\x55\x48\x8b\x05\xb8\x13\x00\x00"
for i in md.disasm(code, 0x1000):
    print("0x%x:\t%s\t%s" % (i.address, i.mnemonic, i.op_str))

# ARM
md_arm = Cs(CS_ARCH_ARM, CS_MODE_ARM)

# MIPS
md_mips = Cs(CS_ARCH_MIPS, CS_MODE_MIPS32)
```

### 5. Binary Analysis

#### File
Identify file types.

```bash
# Basic usage
file binary

# Show MIME type
file -i binary

# Brief mode
file -b binary

# Follow symlinks
file -L binary
```

#### Hexdump / xxd
View binary data in hex.

```bash
# xxd (hex dump)
xxd binary | less
xxd -l 100 binary       # First 100 bytes
xxd -s 0x100 binary     # Start at offset 0x100

# hexdump
hexdump -C binary | less
hexdump -C -n 100 binary  # First 100 bytes
```

## Usage Examples

### Example 1: Basic Binary Analysis

```bash
# 1. Identify the binary
file suspicious_binary
# Output: ELF 64-bit LSB executable, x86-64

# 2. Check for strings
strings suspicious_binary | grep -i password
strings suspicious_binary | grep -i http

# 3. Examine ELF structure
readelf -h suspicious_binary  # Header
readelf -S suspicious_binary  # Sections
readelf -s suspicious_binary  # Symbols

# 4. Disassemble main function
objdump -d suspicious_binary | less
# or
r2 -A suspicious_binary
[0x00000000]> pdf @main
```

### Example 2: Finding Buffer Overflow

```bash
# 1. Debug the program
gdb ./vulnerable

# 2. Run with large input
(gdb) run < <(python3 -c "print('A'*1000)")

# 3. Check for crash
# If segfault, check registers
(gdb) info registers

# 4. Find exact offset with pwntools
python3 << EOF
from pwn import *
print(cyclic(1000))
EOF

# 5. Determine offset
python3 -c "from pwn import *; print(cyclic_find(0x61616161))"
```

### Example 3: ROP Chain Building

```python
#!/usr/bin/env python3
from pwn import *

# Load binary
elf = ELF('./vulnerable')
rop = ROP(elf)

# Find gadgets
libc = ELF('/lib/libc.so.6')

# Build ROP chain
rop.call('puts', [elf.got['puts']])
rop.call(elf.symbols['main'])

# Create payload
offset = 72
payload = flat([
    b'A' * offset,
    rop.chain()
])

# Send exploit
p = process('./vulnerable')
p.sendline(payload)
leak = u64(p.recvline().strip().ljust(8, b'\x00'))
print(f"Leaked puts: {hex(leak)}")
```

### Example 4: Network Service Analysis

```bash
# 1. Scan the target
nmap -sV -p- target.com

# 2. Connect to service
nc target.com 1337

# 3. Capture traffic
tcpdump -i any -w capture.pcap host target.com &

# 4. Fuzz the service
python3 << EOF
from pwn import *
r = remote('target.com', 1337)
r.sendline(cyclic(1000))
r.interactive()
EOF

# 5. Analyze captured traffic
tcpdump -r capture.pcap -A
```

## iSH-Specific Considerations

### Performance

#### x86 Emulation
iSH emulates x86 on ARM processors, which means:
- Programs run slower than native
- CPU-intensive tasks (fuzzing, compilation) are slow
- Analysis tools work but may be laggy

**Tips:**
- Use pre-compiled tools when available
- Avoid heavy compilation tasks
- Work with smaller binaries
- Be patient with analysis tasks

#### Memory Limitations
iOS devices have limited memory:
- Avoid loading huge binaries
- Close other iOS apps
- Monitor memory usage with `free -h`

### Storage Management

#### Check Available Space
```bash
df -h
```

#### Clean Package Cache
```bash
# Clean APK cache
apk cache clean

# Remove package
apk del package_name

# Purge (remove configs too)
apk del --purge package_name
```

#### Compressed Files
Always compress large files:
```bash
tar -czf analysis.tar.gz analysis_files/
xz -9 large_binary  # Better compression
```

### iOS Sandbox Restrictions

#### What Works
✅ Network connections (HTTP, SSH, etc.)
✅ File system operations (within iSH)
✅ Process debugging (within iSH)
✅ Python scripting
✅ Binary analysis
✅ Network scanning (external targets)

#### What Doesn't Work
❌ Kernel modules
❌ Raw sockets (some tools)
❌ Hardware access
❌ iOS filesystem access (outside iSH)
❌ Some syscalls
❌ Real-time scheduling

### Alpine Linux Differences

#### musl libc vs glibc
Alpine uses musl libc instead of glibc:
- Different behavior in some edge cases
- Some binaries expecting glibc won't work
- Python C extensions may need special builds

**Solution:** Use Alpine-native packages when available

#### Package Management
```bash
# Search packages
apk search <keyword>

# Get package info
apk info <package>

# List files in package
apk info -L <package>

# Update repository
apk update

# Upgrade all packages
apk upgrade

# Add testing repository (more packages)
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
apk update
```

### Networking in iSH

#### Port Limitations
- Some low ports may require additional setup
- High ports (>1024) usually work fine

#### SSH Server
```bash
# Install OpenSSH
apk add openssh

# Start SSH daemon
/usr/sbin/sshd

# Connect from other device
ssh user@<iphone-ip>
```

#### File Transfer
```bash
# Using nc (netcat)
# On iPhone:
nc -l -p 8888 > received_file

# On computer:
nc <iphone-ip> 8888 < file_to_send

# Using Python HTTP server
python3 -m http.server 8000
# Access from browser: http://<iphone-ip>:8000
```

## Bug Bounty Workflow

### 1. Target Acquisition
```bash
# Download target binary
wget https://example.com/target_app
chmod +x target_app

# Or transfer from iOS
# Use Files app to move binary into iSH
```

### 2. Initial Analysis
```bash
# Identify binary type
file target_app

# Check protections
checksec target_app  # If available

# Extract strings
strings target_app | tee strings.txt
grep -i "password\|secret\|key\|api" strings.txt

# Check for interesting functions
nm target_app | grep -E "admin|debug|test"
```

### 3. Static Analysis
```bash
# Disassemble with radare2
r2 -A target_app
[0x00000000]> afl | grep -E "admin|debug"
[0x00000000]> pdf @sym.vulnerable_function

# Check for common vulnerabilities
# - Buffer overflows (strcpy, sprintf, gets)
# - Format strings (%s, %x without validation)
# - Integer overflows
# - Use-after-free patterns
```

### 4. Dynamic Analysis
```bash
# Run with debugger
gdb ./target_app

# Trace system calls
strace -f ./target_app

# Monitor network
tcpdump -i any &
./target_app
```

### 5. Fuzzing
```python
#!/usr/bin/env python3
from pwn import *

# Simple fuzzer
for size in range(0, 1000, 50):
    try:
        p = process('./target_app')
        p.sendline(b'A' * size)
        p.recvall(timeout=1)
        p.close()
        print(f"[+] {size} bytes: OK")
    except:
        print(f"[!] {size} bytes: CRASH")
        break
```

### 6. Exploitation
```python
#!/usr/bin/env python3
from pwn import *

context.binary = './target_app'
elf = ELF('./target_app')

# Build exploit
payload = fit({
    64: p64(elf.symbols['win_function'])
})

# Test locally
p = process('./target_app')
p.sendline(payload)
p.interactive()

# Test remotely
# r = remote('target.com', 1337)
# r.sendline(payload)
# r.interactive()
```

### 7. Documentation
Create a professional report:

```markdown
# Vulnerability Report

## Summary
- **Vulnerability Type**: Buffer Overflow
- **Severity**: High
- **Component**: target_app v1.2.3
- **Impact**: Remote Code Execution

## Technical Details
The application contains a stack-based buffer overflow in the
`process_input()` function at offset 0x401234.

## Proof of Concept
[Include PoC code]

## Reproduction Steps
1. Run target_app
2. Send payload: [payload hex]
3. Observe crash with RIP control

## Recommended Fix
Use strncpy() instead of strcpy() with proper bounds checking.
```

## Troubleshooting

### Package Installation Fails

**Problem:** `apk add package` fails
```bash
# Update repositories first
apk update

# Check if package exists
apk search package_name

# Try edge repository
echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
apk update
```

### Python Package Won't Install

**Problem:** `pip install` fails
```bash
# Install build dependencies
apk add python3-dev gcc musl-dev libffi-dev

# Try installing
pip3 install package_name

# Use --no-cache-dir for space
pip3 install --no-cache-dir package_name
```

### GDB Crashes or Hangs

**Problem:** GDB doesn't work properly
```bash
# Disable GEF if causing issues
mv ~/.gdbinit ~/.gdbinit.bak

# Use minimal gdb
gdb -nx ./binary

# Or use lldb instead
lldb ./binary
```

### Out of Storage Space

**Problem:** Disk full error
```bash
# Check usage
df -h

# Clean package cache
apk cache clean

# Remove build dependencies if installed
apk del gcc g++ make cmake

# Compress old files
tar -czf old_analysis.tar.gz old_analysis/
rm -rf old_analysis/
```

### Tool Not Found

**Problem:** Command not found
```bash
# Verify installation
which tool_name

# Check if package installed
apk info | grep tool_name

# Reinstall
apk add tool_name

# Check verification script
~/check_ish_tools.sh
```

### Slow Performance

**Problem:** Tools running very slowly
- This is expected with x86 emulation
- Use simpler tools when available
- Work with smaller binaries
- Close other iOS apps
- Restart iSH if it becomes unresponsive

### Network Tools Require Root

**Problem:** "Operation not permitted"
```bash
# Some tools need root
# iSH runs as root by default, so this shouldn't happen

# If needed, check permissions
id

# Some operations may not work due to iOS sandbox
# This is a limitation, not a bug
```

## Best Practices

### Security Research Ethics

✅ **DO:**
- Only test authorized targets
- Follow bug bounty program rules
- Practice responsible disclosure
- Document findings professionally
- Respect scope and limitations
- Give vendors time to patch

❌ **DON'T:**
- Test unauthorized systems
- Exploit vulnerabilities maliciously
- Share exploits publicly before disclosure
- Ignore program rules
- Exfiltrate user data
- Cause service disruption

### Efficient Tool Usage

#### Use Appropriate Tools
- Simple tasks → simple tools (grep, strings)
- Complex analysis → advanced tools (radare2, gdb)

#### Conserve Resources
```bash
# Remove after use
apk del <large-package>

# Compress results
tar -czf results.tar.gz results/

# Work incrementally
# Don't try to analyze everything at once
```

#### Organize Your Work
```bash
# Create project directories
mkdir -p ~/projects/target_name/{analysis,exploits,reports}

# Document as you go
echo "Found buffer overflow at 0x401234" >> notes.txt

# Keep clean working directory
rm -f core *.o *.pyc
```

### Learning Resources

#### Practice Platforms
- **picoCTF**: https://picoctf.org
- **HackTheBox**: https://hackthebox.eu
- **TryHackMe**: https://tryhackme.com
- **OverTheWire**: https://overthewire.org

#### Bug Bounty Platforms
- **HackerOne**: https://hackerone.com
- **Bugcrowd**: https://bugcrowd.com
- **Apple Security Bounty**: Official Apple program
- **Intigriti**: https://intigriti.com

#### Documentation
- **Pwntools**: https://docs.pwntools.com
- **Radare2 Book**: https://book.rada.re
- **GEF**: https://hugsy.github.io/gef
- **CTF Field Guide**: https://trailofbits.github.io/ctf

### Backup Your Work

#### Regular Backups
```bash
# Compress important files
tar -czf backup_$(date +%Y%m%d).tar.gz ~/projects

# Transfer to iOS Files app
# Or upload to cloud storage
```

#### Git Integration
```bash
# Install git
apk add git

# Initialize repo
git init ~/projects/target_analysis
cd ~/projects/target_analysis
git add .
git commit -m "Initial analysis"

# Push to GitHub (if desired)
git remote add origin <your-repo-url>
git push -u origin main
```

## Advanced Tips

### Custom Tool Installation

#### Building from Source
```bash
# Install build tools
apk add build-base git cmake

# Clone and build
git clone https://github.com/project/tool
cd tool
./configure
make
make install  # Or copy binary manually
```

#### Python Virtual Environments
```bash
# Install venv
apk add python3-venv

# Create environment
python3 -m venv ~/venvs/research
source ~/venvs/research/bin/activate

# Install packages in venv
pip install pwntools ropper
```

### Automation Scripts

#### Quick Analysis Script
```bash
#!/bin/sh
# quick_analysis.sh - Quick binary analysis

BINARY=$1

echo "=== File Type ==="
file "$BINARY"

echo "\n=== Strings (interesting) ==="
strings "$BINARY" | grep -iE "password|key|secret|admin|debug" | head -20

echo "\n=== Functions ==="
nm "$BINARY" | grep " T " | head -20

echo "\n=== Security Features ==="
readelf -l "$BINARY" | grep -E "GNU_STACK|GNU_RELRO"
```

#### Auto-Fuzzer
```python
#!/usr/bin/env python3
# auto_fuzz.py - Simple automatic fuzzer

from pwn import *
import sys

target = sys.argv[1]

for size in range(0, 2000, 100):
    for char in [b'A', b'%s', b'\x00', b'\xff']:
        try:
            p = process(target)
            p.sendline(char * size)
            output = p.recvall(timeout=1)
            p.close()
            print(f"[+] {char} * {size}: OK")
        except:
            print(f"[!] {char} * {size}: CRASH!")
            sys.exit(0)
```

## Conclusion

iSH provides a powerful Linux environment on iOS, enabling professional security research and bug bounty hunting from your mobile device. While there are limitations due to emulation and iOS sandboxing, the toolkit provides all essential tools needed for effective vulnerability research.

### Quick Reference Card

```bash
# Installation
./ish_bugbounty_toolkit.sh --standard

# Verification
~/check_ish_tools.sh

# Quick Start Guide
less ~/ish_bugbounty_quickstart.md

# Package Management
apk search <keyword>
apk add <package>
apk del <package>

# Essential Tools
gdb ./binary              # Debug
strace ./binary           # Trace syscalls
r2 -A ./binary           # Reverse engineer
strings ./binary         # Extract strings
nmap target.com          # Network scan
python3 exploit.py       # Run exploit

# Help
gdb --help
r2 -h
ropper --help
python3 -c "import pwn; help(pwn)"
```

Happy hunting! 🎯💰📱

---

**For Authorized Security Research Only**
Always follow responsible disclosure practices and respect bug bounty program terms.

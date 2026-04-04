# Termux Bug Bounty Toolkit Guide

> Professional security research and bug bounty tools for Termux on Android
> Native ARM performance for mobile penetration testing

## Table of Contents

- [What is Termux?](#what-is-termux)
- [Quick Start](#quick-start)
- [Installation Profiles](#installation-profiles)
- [Tool Categories](#tool-categories)
- [Mobile-Specific Tools](#mobile-specific-tools)
- [Android App Analysis](#android-app-analysis)
- [Termux-Specific Features](#termux-specific-features)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

## What is Termux?

**Termux** is a powerful terminal emulator and Linux environment for Android that runs without rooting your device.

### Key Advantages Over iSH
- ✅ **Native ARM** - No emulation, full CPU performance
- ✅ **Android Integration** - Access device features via termux-api
- ✅ **More Packages** - Larger repository than Alpine
- ✅ **Mobile App Analysis** - Frida, Objection, APKTool
- ✅ **Better Performance** - Native execution vs x86 emulation

### System Requirements
- Android 7.0 (API 24) or higher
- 500MB-2GB free storage (profile dependent)
- Termux app from F-Droid (recommended) or Play Store

## Quick Start

### 1. Install Termux
Download from:
- **F-Droid** (recommended): https://f-droid.org/packages/com.termux/
- Play Store (older version)

### 2. Setup Storage Access
```bash
termux-setup-storage
# Grant storage permission when prompted
```

### 3. Update Packages
```bash
pkg update && pkg upgrade
```

### 4. Run Installer
```bash
# Download installer
wget https://raw.githubusercontent.com/yourrepo/termux_bugbounty_toolkit.sh
chmod +x termux_bugbounty_toolkit.sh

# Install standard profile (recommended)
./termux_bugbounty_toolkit.sh --standard
```

### 5. Verify
```bash
~/check_termux_tools.sh
```

## Installation Profiles

### Minimal (~100-200MB)
Essential debugging tools for ARM architecture.

**Includes:**
- GDB, strace, ltrace
- Binutils (objdump, readelf)
- Python 3 + pip
- Git, curl, wget, SSH
- Text editors (vim, nano)
- Basic compression tools

**Install:**
```bash
./termux_bugbounty_toolkit.sh --minimal
```

### Standard (~500MB-1GB) **[RECOMMENDED]**
Complete bug bounty toolkit with mobile analysis tools.

**Adds:**
- Radare2 reverse engineering
- Nmap, Netcat, Socat
- Pwntools, Ropper, Capstone
- Node.js, Ruby, Perl
- Build tools (clang, cmake)
- GDB Enhanced Features

**Install:**
```bash
./termux_bugbounty_toolkit.sh --standard
```

### Full (~1-2GB)
Everything including mobile-specific tools.

**Adds:**
- Frida + Frida-tools
- Objection (Frida framework)
- APKTool (if available)
- Metasploit (if available)
- Advanced Python tools (Angr, Impacket)
- Wireshark/tshark
- Fuzzing tools

**Install:**
```bash
./termux_bugbounty_toolkit.sh --full
```

## Tool Categories

### 1. Core Debugging

#### GDB with GEF
```bash
# Debug ARM binaries natively
gdb ./arm_binary

# GEF commands
gef> vmmap                    # Memory mappings
gef> checksec                 # Binary protections
gef> pattern create 200       # Cyclic pattern
gef> pattern offset 0x41414141
gef> heap chunks              # Heap analysis
gef> rop                      # Find ROP gadgets
```

#### Pwndbg (Alternative)
```bash
# Install instead of GEF
./termux_bugbounty_toolkit.sh --pwndbg-only

# Similar commands to GEF
pwndbg> vmmap
pwndbg> checksec
pwndbg> cyclic 200
```

### 2. Reverse Engineering

#### Radare2 (Native ARM)
```bash
r2 ./binary
[0x00000000]> aa          # Analyze
[0x00000000]> afl         # List functions
[0x00000000]> pdf @main   # Disassemble
[0x00000000]> VV          # Visual graph
[0x00000000]> /R pop {pc} # Search ARM gadgets
```

### 3. Network Tools

#### Nmap
```bash
# Full network scanning
nmap -sV -A target.com

# All ports
nmap -p- 192.168.1.100

# Specific scripts
nmap --script vuln target.com
```

#### Netcat & Socat
```bash
# Listen
nc -l -p 4444

# Connect
nc target.com 1337

# Socat port forward
socat TCP-LISTEN:8080,fork TCP:target:80
```

### 4. Python Security Tools

#### Pwntools (ARM-native)
```python
#!/data/data/com.termux/files/usr/bin/python
from pwn import *

# ARM context
context.arch = 'arm'
context.os = 'linux'

# Or aarch64
context.arch = 'aarch64'

# Connect
r = remote('target.com', 1337)

# Build ARM payload
payload = asm('''
    mov r0, #0
    mov r7, #1
    svc #0
''')

r.sendline(payload)
r.interactive()
```

## Mobile-Specific Tools

### Frida (Dynamic Instrumentation)

#### Installation
```bash
pip install frida frida-tools
```

#### Hooking Android Apps
```bash
# List running apps
frida-ps -U

# Attach to app
frida -U -n com.example.app

# Run script
frida -U -f com.example.app -l hook.js
```

#### Example Hook Script
```javascript
// hook.js
Java.perform(function() {
    var MainActivity = Java.use('com.example.MainActivity');

    MainActivity.checkPassword.implementation = function(password) {
        console.log('[+] Password: ' + password);
        return this.checkPassword(password);
    };
});
```

### Objection (Frida Framework)

#### Usage
```bash
# Explore app
objection -g com.example.app explore

# Common commands
com.example.app on (android) > android hooking list activities
com.example.app on (android) > android hooking watch class_method com.example.MainActivity.checkPassword --dump-args
com.example.app on (android) > android sslpinning disable
com.example.app on (android) > android root disable
com.example.app on (android) > memory list modules
```

### APKTool (Decompilation)

```bash
# Decompile APK
apktool d app.apk -o app_source

# Examine manifest
cat app_source/AndroidManifest.xml

# Rebuild
apktool b app_source -o modified.apk

# Sign
jarsigner -keystore my.keystore modified.apk alias_name
```

## Termux-Specific Features

### Storage Access

```bash
# Setup (run once)
termux-setup-storage

# Access directories
ls ~/storage/dcim          # Camera
ls ~/storage/downloads     # Downloads
ls ~/storage/shared        # Shared storage

# Copy files
cp exploit.py ~/storage/downloads/
```

### Termux API

Install Termux:API app for extended features:

```bash
# Install API package
pkg install termux-api

# Send notification
termux-notification -t "Scan Complete" -c "Found vulnerabilities"

# Copy to clipboard
echo "192.168.1.100" | termux-clipboard-set

# Paste from clipboard
termux-clipboard-get

# Get location
termux-location

# Take photo
termux-camera-photo photo.jpg

# Record audio
termux-microphone-record -f recording.mp3
```

### Wake Lock (Prevent Sleep)

```bash
# Acquire wake lock for long scans
termux-wake-lock

# Run long task
nmap -p- -sV target.com

# Release wake lock
termux-wake-unlock
```

### File Sharing

```bash
# Start HTTP server
python -m http.server 8000
# Access from computer: http://phone-ip:8000

# Share file via Android
termux-share exploit.py

# Open in Android app
termux-open report.pdf
```

## Android App Analysis

### 1. APK Extraction

```bash
# Pull APK from device (requires ADB or root)
# If rooted:
su -c "cp /data/app/com.example.app/base.apk /sdcard/"
cp ~/storage/shared/base.apk ./app.apk

# Or use ADB from computer
# adb pull /data/app/com.example.app/base.apk
```

### 2. Static Analysis

```bash
# Decompile
apktool d app.apk

# Examine manifest
cat app/AndroidManifest.xml | grep -E "permission|exported"

# Search for secrets
grep -r "api_key\|password\|secret" app/

# Find URLs
grep -r "http://" app/
```

### 3. Dynamic Analysis with Frida

```javascript
// hook-crypto.js
Java.perform(function() {
    // Hook crypto operations
    var Cipher = Java.use('javax.crypto.Cipher');

    Cipher.doFinal.overload('[B').implementation = function(data) {
        console.log('[+] Cipher.doFinal called');
        console.log('[+] Data: ' + hexdump(data));

        var result = this.doFinal(data);
        console.log('[+] Result: ' + hexdump(result));
        return result;
    };
});

function hexdump(arr) {
    var output = '';
    for (var i = 0; i < arr.length; i++) {
        output += ('0' + (arr[i] & 0xFF).toString(16)).slice(-2) + ' ';
    }
    return output;
}
```

Run:
```bash
frida -U -f com.example.app -l hook-crypto.js
```

### 4. SSL Pinning Bypass

```bash
# With Objection
objection -g com.example.app explore
android sslpinning disable

# Or with Frida script
frida -U -f com.example.app -l ssl-bypass.js
```

### 5. Root Detection Bypass

```bash
# With Objection
objection -g com.example.app explore
android root disable

# Or patch APK
apktool d app.apk
# Edit smali code
apktool b app/ -o patched.apk
```

## Usage Examples

### Example 1: Network Service Analysis

```bash
# Scan target
nmap -sV -p- target.com

# Connect and explore
nc target.com 1337

# Build exploit
cat > exploit.py << 'PYEOF'
from pwn import *

r = remote('target.com', 1337)
r.sendline(cyclic(1000))
r.interactive()
PYEOF

python exploit.py
```

### Example 2: Mobile App Vulnerability

```bash
# 1. Extract APK
cp ~/storage/downloads/target.apk .

# 2. Decompile
apktool d target.apk

# 3. Find exported components
grep "exported=\"true\"" target/AndroidManifest.xml

# 4. Test with ADB intent
am start -n com.example/.SecretActivity

# 5. Hook with Frida
frida -U -f com.example -l hook.js
```

### Example 3: ARM Binary Exploitation

```python
#!/data/data/com.termux/files/usr/bin/python
from pwn import *

# ARM context
context.arch = 'arm'
context.os = 'linux'

# Load binary
elf = ELF('./vulnerable_arm')

# Find offset
offset = 64

# Build ROP chain
rop = ROP(elf)
rop.call(elf.symbols['system'], [next(elf.search(b'/bin/sh'))])

# Create payload
payload = flat([
    b'A' * offset,
    rop.chain()
])

# Exploit
p = process('./vulnerable_arm')
p.sendline(payload)
p.interactive()
```

## Best Practices

### Battery Management
```bash
# Use wake lock for long tasks
termux-wake-lock
nmap -p- target.com
termux-wake-unlock

# Or schedule for charging
# Run scans when plugged in
```

### Storage Management
```bash
# Clean package cache
pkg clean

# Remove unused packages
pkg autoremove

# Compress old data
tar -czf old_scans.tar.gz scans/
rm -rf scans/
```

### Network Testing
```bash
# Check your IP
curl ifconfig.me

# Test from different networks
# - Mobile data
# - WiFi
# - VPN

# Use tethering for isolated testing
```

### Security
```bash
# Don't store credentials in plain text
# Use environment variables
export API_KEY="..."

# Or use pass/password manager
pkg install pass
```

## Termux vs iSH Comparison

| Feature | Termux (Android) | iSH (iOS) |
|---------|-----------------|-----------|
| Architecture | Native ARM | x86 emulation |
| Performance | Excellent | Moderate |
| Package Manager | pkg (APT-based) | apk (Alpine) |
| Root Access | Possible (rooted device) | No |
| Mobile Features | Full (Termux API) | Limited |
| App Analysis | Yes (Frida, APKTool) | No |
| Battery Impact | Higher | Lower |
| Filesystem Access | Full (with storage) | Sandboxed |

## Advanced Tips

### SSH Server on Android
```bash
# Install OpenSSH
pkg install openssh

# Start server
sshd

# Find your IP
ifconfig | grep inet

# Connect from computer
ssh -p 8022 user@phone-ip
```

### Automation with Cron
```bash
# Install cronie
pkg install cronie

# Start cron
crond

# Edit crontab
crontab -e

# Example: Daily security scan
0 2 * * * ~/scripts/daily_scan.sh
```

### Custom Aliases
```bash
# Add to ~/.bashrc
echo "alias ll='ls -la'" >> ~/.bashrc
echo "alias scan='nmap -sV'" >> ~/.bashrc
echo "alias r2='radare2 -A'" >> ~/.bashrc

source ~/.bashrc
```

## Troubleshooting

### Package Installation Fails
```bash
# Update repositories
pkg update

# Clear cache
pkg clean

# Reinstall
pkg reinstall package-name
```

### Python Package Issues
```bash
# Install build dependencies
pkg install python-dev clang

# Use --no-binary
pip install --no-binary :all: package-name
```

### Permission Denied
```bash
# For files
chmod +x script.sh

# For termux-api features
# Reinstall Termux:API app

# For root operations
pkg install tsu
tsu -c "command"
```

## Resources

- **Termux Wiki**: https://wiki.termux.com/
- **Termux Packages**: https://github.com/termux/termux-packages
- **Frida**: https://frida.re/
- **Objection**: https://github.com/sensepost/objection
- **Android Security**: https://source.android.com/security

## Conclusion

Termux provides a powerful, native ARM environment for security research on Android. With full mobile app analysis capabilities, native performance, and Android integration, it's an essential tool for mobile bug bounty hunting.

Happy hunting! 🎯📱💰

---
**For Authorized Security Research Only**

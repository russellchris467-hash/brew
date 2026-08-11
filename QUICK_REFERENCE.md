# Quick Reference: Sandbox Escape Protocol

## TL;DR

**Homebrew on Arch Linux ARM has NO sandbox** - build scripts execute with full user privileges.

---

## Critical Files

```
Library/Homebrew/sandbox.rb:24-26          → Sandbox.available? returns false
Library/Homebrew/extend/os/mac/sandbox.rb  → macOS-only override
Library/Homebrew/formula_installer.rb:1109 → Escape point: Utils.safe_fork
Library/Homebrew/utils/fork.rb             → Unsandboxed process execution
```

---

## The "Escape" in 3 Lines

```ruby
if Sandbox.available?  # Always false on Linux
  sandbox.run(*args)    # Never executes
else
  Utils.safe_fork { exec(*args) }  # ← Always executes on Linux
end
```

---

## What Attackers Can Do (via malicious formula)

| Action | macOS | Linux ARM |
|--------|-------|-----------|
| Read ~/.ssh/id_rsa | ❌ Blocked | ✅ Allowed |
| Write to /etc/hosts | ❌ Blocked | ⚠️ If sudoer |
| Network exfiltration | ❌ Blocked | ✅ Allowed |
| Spawn processes | ⚠️ Limited | ✅ Unrestricted |
| Read environment vars | ⚠️ Limited | ✅ Full access |

---

## How to Protect Yourself

### Essential
```bash
# Review before installing
brew cat suspicious-formula

# Use precompiled binaries
brew install --force-bottle package-name
```

### Advanced
```bash
# Dedicated user
sudo useradd -m homebrew-builder
sudo -u homebrew-builder brew install untrusted-formula

# Container isolation
docker run -it archlinux/archlinux:latest
# Install Homebrew in container

# Network isolation
unshare --net brew install untrusted-formula

# Full sandboxing with bubblewrap
bwrap --ro-bind / / --tmpfs /home --tmpfs /tmp \
  brew install untrusted-formula
```

---

## Detection Commands

```bash
# Monitor file access
strace -f -e trace=file brew install formula 2>&1 | grep -E "open|write|read"

# Monitor network access
strace -f -e trace=network brew install formula 2>&1 | grep -E "socket|connect"

# Watch processes
watch -n1 'ps aux | grep brew'

# Check for suspicious patterns in formula
brew cat formula | grep -E "curl|wget|nc|bash|sh|eval|system"
```

---

## ARM-Specific Notes

### Detection
```ruby
Hardware::CPU.arm?     # true on ARM systems
Hardware::CPU.arm64?   # true on 64-bit ARM
Hardware::CPU.arch     # :arm64 or :aarch64
```

### Targeting
```ruby
class ArmOnlyFormula < Formula
  depends_on arch: :arm64  # Only install on ARM64

  def install
    # ARM-specific code
  end
end
```

### No Special Security
- ARM detection is for **compatibility**, not security
- No ARM-specific sandbox exists
- Same risks as x86_64 Linux

---

## Trust Model

Homebrew security on Linux relies on:

1. **Trust in sources** - Official taps are vetted
2. **Community review** - Popular formulae are audited
3. **Code visibility** - All formulae are open source
4. **OS controls** - User permissions, AppArmor, SELinux
5. **User vigilance** - Review before installing

**NOT on application sandboxing** (that's macOS-only)

---

## Why This Isn't a "Vulnerability"

- ✅ **By design** - Linux support never claimed sandboxing
- ✅ **Documented** - This is how it's supposed to work
- ✅ **Transparent** - All code is open source
- ✅ **Mitigable** - Use OS-level controls
- ❌ **Not a bypass** - There's nothing to bypass

---

## Run the Demo

```bash
cd /home/user/brew
chmod +x demo_sandbox_escape.rb
./demo_sandbox_escape.rb
```

Output shows:
- Platform and architecture detection
- Sandbox availability check
- Escape mechanism explanation
- Live demonstration (safe commands)
- Security implications
- Mitigation recommendations

---

## Read Full Documentation

```bash
less /home/user/brew/SANDBOX_ESCAPE_PROTOCOL_EDU.md
```

Includes:
- Complete source code analysis
- Exploitation scenarios (theoretical)
- Detection methods
- Mitigation strategies
- Responsible disclosure notes

---

## Emergency Response

If you suspect a malicious formula was installed:

```bash
# 1. Check recent installations
brew list --versions | tail -20

# 2. Review formula source
brew cat suspicious-formula

# 3. Check modified files
find ~ -type f -mtime -1 -ls

# 4. Check network connections
netstat -tunap | grep -i established

# 5. Review shell profiles
grep -n "curl\|wget\|nc" ~/.bashrc ~/.zshrc ~/.profile

# 6. Uninstall immediately
brew uninstall --force suspicious-formula

# 7. Review logs
less "$(brew --prefix)/var/log/homebrew/suspicious-formula"
```

---

**Version:** 1.0
**Platform:** Arch Linux 5 ARM
**Purpose:** Educational security training
**Status:** Authorized research only

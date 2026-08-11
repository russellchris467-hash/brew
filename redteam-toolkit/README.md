# 🔴 Arch Linux Red Teaming Toolkit
## 🎯 Homebrew Sandbox Escape Assessment Suite

**Version:** 1.0
**Platform:** Arch Linux ARM
**Purpose:** 🎓 Educational Red Team Training & Authorized Security Assessment
**Status:** ⚠️ FOR AUTHORIZED USE ONLY ⚠️

---

## 🚨 LEGAL DISCLAIMER

**CRITICAL - READ BEFORE USE:**

✅ **AUTHORIZED USE ONLY:**
- This toolkit is for **authorized security testing** and **educational purposes** ONLY
- Requires explicit written authorization before use on any system
- Intended for penetration testing engagements, CTF competitions, and security research
- Use only on systems you own or have explicit permission to test

❌ **PROHIBITED USE:**
- Unauthorized access to computer systems (violates CFAA and international laws)
- Malicious exploitation or destructive activities
- Testing on production systems without authorization
- Any use that violates applicable laws and regulations

🔒 **USER RESPONSIBILITY:**
By using this toolkit, you acknowledge:
1. You have proper authorization for all testing activities
2. You understand applicable laws (CFAA, GDPR, local regulations)
3. You accept full legal responsibility for your actions
4. Misuse may result in criminal prosecution

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Toolkit Components](#toolkit-components)
4. [Installation & Setup](#installation--setup)
5. [Usage Examples](#usage-examples)
6. [Attack Scenarios](#attack-scenarios)
7. [Detection Methods](#detection-methods)
8. [Defense Strategies](#defense-strategies)
9. [Reporting](#reporting)

---

## 🎯 Overview

This red teaming toolkit focuses on **assessing the security implications** of Homebrew's lack of sandboxing on Linux platforms, particularly Arch Linux ARM systems.

### 🎓 Educational Objectives

- ✅ Understand sandbox escape mechanisms on Linux
- ✅ Learn reconnaissance techniques for package manager security
- ✅ Practice exploitation in controlled environments
- ✅ Develop detection and monitoring skills
- ✅ Build defensive security measures

### 🔍 Key Findings (From Research)

| Component | macOS 🍎 | Linux 🐧 | Risk Level |
|-----------|----------|----------|------------|
| Sandbox | ✅ Seatbelt | ❌ None | 🔴 HIGH |
| File Access | 🔒 Restricted | 🔓 Unrestricted | 🔴 HIGH |
| Network | 🔒 Controlled | 🔓 Unrestricted | 🟡 MEDIUM |
| Process Isolation | ✅ Yes | ⚠️ Basic Fork | 🟡 MEDIUM |

---

## 🏗️ Architecture

### Toolkit Structure

```
redteam-toolkit/
├── 📁 recon/           # Reconnaissance & enumeration tools
│   ├── 🔍 system_enum.rb
│   ├── 🏗️ homebrew_profile.rb
│   ├── 🔐 security_audit.rb
│   └── 📊 attack_surface.rb
│
├── 📁 exploits/        # Proof-of-concept demonstrations
│   ├── 💣 data_exfil_poc.rb
│   ├── 🚪 privilege_persist.rb
│   ├── 🌐 network_beacon.rb
│   └── 🎭 stealth_payload.rb
│
├── 📁 detection/       # Monitoring & detection utilities
│   ├── 👁️ process_monitor.rb
│   ├── 📡 network_watch.rb
│   ├── 📂 file_integrity.rb
│   └── 🔔 alert_system.rb
│
├── 📁 defense/         # Defensive countermeasures
│   ├── 🛡️ sandbox_wrapper.rb
│   ├── 🔒 formula_validator.rb
│   ├── 🚫 network_isolator.sh
│   └── 📦 container_builder.sh
│
└── 📁 reports/         # Assessment reports & templates
    ├── 📄 pentest_template.md
    ├── 📊 findings_report.md
    └── 🎯 remediation_plan.md
```

---

## 🛠️ Toolkit Components

### 1️⃣ Reconnaissance Tools 🔍

**Purpose:** Enumerate system configuration and identify attack surface

- **system_enum.rb** - Complete system profiling
  - OS version and architecture detection
  - Homebrew installation analysis
  - User permissions enumeration
  - Installed formula inventory

- **homebrew_profile.rb** - Homebrew-specific reconnaissance
  - Sandbox availability testing
  - Formula source analysis
  - Tap configuration review
  - Bottle vs source-build detection

- **security_audit.rb** - Security posture assessment
  - File permission analysis
  - Environment variable exposure
  - Network configuration review
  - SELinux/AppArmor status

- **attack_surface.rb** - Attack surface mapping
  - Writable directories identification
  - Network service enumeration
  - Privilege escalation vectors
  - Persistence mechanism opportunities

### 2️⃣ Exploit Demonstrations 💣

**Purpose:** Proof-of-concept demonstrations (EDUCATIONAL ONLY)

- **data_exfil_poc.rb** - Data exfiltration demonstration
  - File access testing
  - Environment variable harvesting
  - Credential discovery
  - Network exfiltration simulation

- **privilege_persist.rb** - Persistence mechanism demo
  - Shell profile modification
  - Cron job installation
  - Systemd service creation
  - Autostart mechanism implantation

- **network_beacon.rb** - Command & control simulation
  - Network connectivity testing
  - C2 beacon simulation
  - Data channel establishment
  - Covert communication demo

- **stealth_payload.rb** - Evasion techniques
  - Anti-detection methods
  - Log manipulation
  - Process hiding
  - Network obfuscation

### 3️⃣ Detection Utilities 👁️

**Purpose:** Monitor and detect malicious activity

- **process_monitor.rb** - Process activity tracking
  - Homebrew process monitoring
  - Child process detection
  - Syscall monitoring integration
  - Anomaly detection

- **network_watch.rb** - Network activity monitoring
  - Connection tracking
  - Unexpected network activity alerts
  - DNS query monitoring
  - Data exfiltration detection

- **file_integrity.rb** - File system monitoring
  - Critical file monitoring
  - Unexpected modifications detection
  - Permission change alerts
  - SHA256 integrity checking

- **alert_system.rb** - Real-time alerting
  - Multi-channel notifications
  - Severity-based filtering
  - Event correlation
  - Incident response triggering

### 4️⃣ Defensive Countermeasures 🛡️

**Purpose:** Implement security controls and mitigations

- **sandbox_wrapper.rb** - Linux sandbox wrapper
  - Bubblewrap integration
  - Namespace isolation
  - Capability restrictions
  - Seccomp filtering

- **formula_validator.rb** - Formula security scanner
  - Static analysis
  - Dangerous pattern detection
  - Dependency checking
  - Reputation scoring

- **network_isolator.sh** - Network isolation script
  - Network namespace creation
  - Firewall rule management
  - DNS filtering
  - VPN tunneling

- **container_builder.sh** - Container isolation
  - Docker container generation
  - Minimal privilege configuration
  - Volume mounting restrictions
  - Network policy enforcement

---

## 📦 Installation & Setup

### Prerequisites

```bash
# 🐧 Arch Linux packages
sudo pacman -S ruby strace lsof tcpdump bubblewrap docker git

# 💎 Ruby gems
gem install json colorize tty-table tty-prompt

# 🔧 Optional tools
sudo pacman -S wireshark-cli nmap netcat inotify-tools
```

### Setup

```bash
# 📥 Clone or navigate to toolkit
cd /home/user/brew/redteam-toolkit

# 🔑 Make scripts executable
chmod +x recon/*.rb exploits/*.rb detection/*.rb defense/*.rb defense/*.sh

# ✅ Verify installation
ruby recon/system_enum.rb --check
```

---

## 🎮 Usage Examples

### 🔍 Reconnaissance Phase

```bash
# 1️⃣ System enumeration
./recon/system_enum.rb --full

# 2️⃣ Homebrew profiling
./recon/homebrew_profile.rb --analyze

# 3️⃣ Security audit
./recon/security_audit.rb --report

# 4️⃣ Attack surface mapping
./recon/attack_surface.rb --map --output reports/attack_surface.json
```

### 💣 Exploitation Phase (AUTHORIZED ONLY)

```bash
# ⚠️ WARNING: Only run on authorized test systems!

# 1️⃣ Test data exfiltration (safe mode)
./exploits/data_exfil_poc.rb --dry-run --target /tmp/test

# 2️⃣ Persistence demo (non-destructive)
./exploits/privilege_persist.rb --demo --no-write

# 3️⃣ Network beacon (local only)
./exploits/network_beacon.rb --local --port 4444

# 4️⃣ Stealth techniques (analysis mode)
./exploits/stealth_payload.rb --analyze
```

### 👁️ Detection Phase

```bash
# 1️⃣ Start process monitoring
./detection/process_monitor.rb --daemon --log /var/log/redteam/processes.log

# 2️⃣ Network watching
sudo ./detection/network_watch.rb --interface eth0 --alert

# 3️⃣ File integrity monitoring
./detection/file_integrity.rb --watch /home,/etc --baseline

# 4️⃣ Alert system
./detection/alert_system.rb --email admin@example.com --slack webhook-url
```

### 🛡️ Defense Phase

```bash
# 1️⃣ Sandbox wrapper (isolate Homebrew)
./defense/sandbox_wrapper.rb brew install untrusted-formula

# 2️⃣ Formula validation
./defense/formula_validator.rb --scan untrusted-formula --strict

# 3️⃣ Network isolation
sudo ./defense/network_isolator.sh --isolate brew --allow-dns

# 4️⃣ Container deployment
./defense/container_builder.sh --create homebrew-sandbox --secure
```

---

## 🎯 Attack Scenarios

### Scenario 1: 🎭 Malicious Formula Installation

**Objective:** Demonstrate risk of installing untrusted formulae

**Red Team Steps:**
1. 🔍 Reconnaissance: Identify Homebrew installation
2. 📝 Craft malicious formula with data exfiltration payload
3. 🎣 Social engineering to install formula
4. 💣 Trigger execution during build phase
5. 📡 Exfiltrate sensitive data (SSH keys, env vars)
6. 🚪 Establish persistence mechanism

**Blue Team Detection:**
1. 👁️ Process monitoring detects unusual child processes
2. 📡 Network monitoring flags unexpected connections
3. 📂 File integrity alerts on profile modifications
4. 🔔 Alert system triggers incident response

**Defensive Measures:**
- ✅ Formula validation before installation
- ✅ Sandbox wrapper enforcement
- ✅ Network isolation during builds
- ✅ Regular security audits

### Scenario 2: 🌐 Supply Chain Attack

**Objective:** Compromise via dependency poisoning

**Red Team Steps:**
1. 🔍 Identify popular formula with many dependencies
2. 🎯 Target lesser-known dependency
3. 💉 Inject malicious code into dependency
4. ⏳ Wait for formula updates to pull poisoned dependency
5. 🚀 Execute payload during dependency installation

**Blue Team Detection:**
1. 🔍 Dependency hash validation
2. 📊 Reputation monitoring for dependencies
3. 🔔 Alert on dependency changes
4. 📝 Source code diff analysis

**Defensive Measures:**
- ✅ Bottle-only installations (skip builds)
- ✅ Dependency pinning and hash verification
- ✅ Isolated build environments
- ✅ Regular dependency audits

### Scenario 3: 💻 ARM-Specific Targeting

**Objective:** Target ARM architecture systems specifically

**Red Team Steps:**
1. 🔍 Detect ARM architecture
2. 🎯 Deploy ARM-optimized payload
3. 💣 Exploit ARM-specific vulnerabilities
4. 🔐 Target IoT devices and embedded systems
5. 🌐 Lateral movement to ARM cluster

**Blue Team Detection:**
1. 🖥️ Architecture-aware monitoring
2. 🔍 ARM-specific anomaly detection
3. 📊 Cluster-wide visibility
4. 🚨 Correlation across ARM nodes

---

## 🔍 Detection Methods

### Indicators of Compromise (IOCs)

#### 🚩 File System IOCs
```
❌ Unexpected modifications to shell profiles (~/.bashrc, ~/.zshrc)
❌ New files in autostart directories (~/.config/autostart/)
❌ Suspicious cron jobs (crontab -l)
❌ Unknown systemd services
❌ New SSH authorized_keys entries
```

#### 🚩 Network IOCs
```
❌ Unexpected outbound connections during brew install
❌ DNS queries to suspicious domains
❌ High-volume data transfers
❌ Connections to known C2 infrastructure
❌ Non-standard ports usage
```

#### 🚩 Process IOCs
```
❌ Unexpected child processes from brew
❌ Long-running processes after installation completes
❌ Processes with suspicious names
❌ Hidden processes (names starting with spaces/dots)
❌ Privilege escalation attempts
```

### 🔬 Forensic Analysis

```bash
# 📝 Check recent installations
brew list --versions | tail -20

# 🔍 Review formula source
brew cat suspicious-formula

# 📂 Find recently modified files
find ~ /etc -type f -mtime -1 -ls

# 📡 Check active connections
netstat -tunap | grep ESTABLISHED

# 📝 Review shell profiles
grep -Hn "curl\|wget\|nc\|bash -c\|eval" ~/.bashrc ~/.zshrc ~/.profile

# 🔍 Check cron jobs
crontab -l
sudo cat /etc/crontab
ls -la /etc/cron.*

# 📋 Systemd services
systemctl list-units --type=service --state=running
systemctl status suspicious-service

# 📊 Process tree
ps auxf | grep brew
pstree -p
```

---

## 🛡️ Defense Strategies

### 🔒 Layered Security Model

#### Layer 1: Prevention 🚫
- ✅ Only install from official Homebrew taps
- ✅ Use bottles (precompiled) when possible
- ✅ Review formula source before installation
- ✅ Implement formula validation/scanning
- ✅ Use dedicated build user with limited privileges

#### Layer 2: Isolation 📦
- ✅ Container-based builds (Docker/Podman)
- ✅ Network namespace isolation
- ✅ Filesystem restrictions (bubblewrap)
- ✅ Capability dropping
- ✅ Seccomp filtering

#### Layer 3: Monitoring 👁️
- ✅ Real-time process monitoring
- ✅ Network activity tracking
- ✅ File integrity monitoring
- ✅ System call auditing (auditd)
- ✅ Centralized logging

#### Layer 4: Detection 🔍
- ✅ Anomaly detection
- ✅ Behavioral analysis
- ✅ IOC matching
- ✅ Threat intelligence integration
- ✅ SIEM correlation

#### Layer 5: Response 🚨
- ✅ Automated incident response
- ✅ Quarantine capabilities
- ✅ Forensic data collection
- ✅ Rollback mechanisms
- ✅ Threat hunting

### 🔧 Hardening Checklist

```bash
# ✅ 1. Create dedicated Homebrew user
sudo useradd -m -s /bin/bash -G docker homebrew-builder
sudo -u homebrew-builder /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ✅ 2. Restrict file permissions
chmod 700 /home/homebrew-builder
chown -R homebrew-builder:homebrew-builder /home/homebrew-builder

# ✅ 3. Enable AppArmor/SELinux
sudo systemctl enable apparmor
sudo aa-enforce /etc/apparmor.d/*

# ✅ 4. Configure firewall
sudo ufw enable
sudo ufw default deny outgoing
sudo ufw allow out 80/tcp
sudo ufw allow out 443/tcp

# ✅ 5. Enable audit logging
sudo systemctl enable auditd
sudo auditctl -w /home/homebrew-builder -p wa -k homebrew_watch

# ✅ 6. Set environment restrictions
echo 'export HOMEBREW_NO_ENV_HINTS=1' >> ~/.bashrc
echo 'export HOMEBREW_NO_ANALYTICS=1' >> ~/.bashrc

# ✅ 7. Configure file integrity monitoring
sudo apt install aide
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## 📊 Reporting

### 🎯 Penetration Test Report Template

Available at: `reports/pentest_template.md`

**Sections:**
1. Executive Summary
2. Scope and Methodology
3. Findings (Critical/High/Medium/Low)
4. Technical Details
5. Evidence (Screenshots/Logs)
6. Remediation Recommendations
7. Appendices

### 📋 Findings Report

Available at: `reports/findings_report.md`

**Format:**
- Finding ID
- Severity (CVSS score)
- Affected Component
- Description
- Proof of Concept
- Impact Analysis
- Remediation Steps
- References

---

## 🎓 Training Exercises

### Exercise 1: 🔍 Reconnaissance
**Difficulty:** Beginner
**Objective:** Profile a Homebrew installation
**Time:** 30 minutes

1. Run all reconnaissance tools
2. Generate attack surface map
3. Identify top 3 risks
4. Document findings

### Exercise 2: 💣 Safe Exploitation
**Difficulty:** Intermediate
**Objective:** Run PoC exploits in dry-run mode
**Time:** 1 hour

1. Set up isolated test environment
2. Run data exfiltration PoC (dry-run)
3. Test persistence mechanisms (non-destructive)
4. Analyze execution traces

### Exercise 3: 👁️ Detection
**Difficulty:** Intermediate
**Objective:** Detect malicious formula installation
**Time:** 1 hour

1. Deploy all monitoring tools
2. Install test malicious formula
3. Correlate alerts
4. Write detection rules

### Exercise 4: 🛡️ Defense
**Difficulty:** Advanced
**Objective:** Implement complete defensive stack
**Time:** 2 hours

1. Deploy sandbox wrapper
2. Configure network isolation
3. Implement monitoring
4. Test with attack scenarios
5. Validate defenses

---

## 📚 References

### 🔗 External Resources

- [Homebrew Security](https://docs.brew.sh/Security)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [MITRE ATT&CK](https://attack.mitre.org/)
- [Bubblewrap Sandboxing](https://github.com/containers/bubblewrap)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Seccomp Filtering](https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html)

### 📄 Internal Documentation

- [Sandbox Escape Protocol](../SANDBOX_ESCAPE_PROTOCOL_EDU.md)
- [Quick Reference](../QUICK_REFERENCE.md)
- [Demo Script](../demo_sandbox_escape_standalone.rb)

---

## 🤝 Contributing

This is an educational toolkit. Contributions welcome:

1. 🐛 Bug fixes
2. ✨ New detection methods
3. 🛡️ Additional defenses
4. 📚 Documentation improvements
5. 🎓 Training scenarios

**Please ensure all contributions:**
- Are clearly educational
- Include proper warnings
- Follow ethical guidelines
- Don't include real malware

---

## 📜 License

**Educational Use Only**

This toolkit is provided for educational and authorized security testing purposes only. Users are responsible for compliance with all applicable laws and regulations.

---

## ⚠️ Final Warning

🚨 **UNAUTHORIZED USE IS ILLEGAL** 🚨

Using this toolkit without proper authorization may violate:
- Computer Fraud and Abuse Act (CFAA) - USA
- Computer Misuse Act - UK
- Similar laws in your jurisdiction

**Penalties may include:**
- Criminal prosecution
- Imprisonment
- Heavy fines
- Civil liability

**ALWAYS:**
- ✅ Get written authorization
- ✅ Work within defined scope
- ✅ Follow rules of engagement
- ✅ Document everything
- ✅ Act ethically

---

**Version:** 1.0
**Last Updated:** 2026-01-03
**Maintainer:** Red Team Education Initiative
**Status:** 🎓 Educational Research Only

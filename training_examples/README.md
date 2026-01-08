# Offensive Security Training Materials

Educational resources for learning social engineering, package exploitation, and OSINT techniques for **authorized security testing and training purposes only**.

---

## ⚠️ WARNING

These materials are for **educational purposes only**. Use only in:
- Personal training labs
- Authorized penetration tests
- CTF competitions
- Academic research with ethical approval
- Defensive security training

**Never:**
- Deploy to real package repositories
- Test on systems without authorization
- Use for malicious purposes
- Violate computer fraud and abuse laws

---

## 📚 Contents

### 1. Main Training Document
**[OFFENSIVE_SECURITY_TRAINING.md](../OFFENSIVE_SECURITY_TRAINING.md)**

Comprehensive guide covering:
- High-level social engineering plan
- Targeted package program design
- OSINT tools and integration
- Complete attack scenarios
- Detection and defense strategies
- Training exercises
- Legal and ethical considerations

### 2. Lab Setup Guide
**[LAB_SETUP_GUIDE.md](./LAB_SETUP_GUIDE.md)**

Step-by-step instructions for creating a safe training environment:
- Virtual machine setup (VirtualBox/Docker)
- Attacker VM configuration (Kali Linux)
- Victim VM setup (Ubuntu)
- Network isolation
- Tool installation
- Exercise deployment

### 3. Example Code

#### Malicious Homebrew Formula
**[malicious_formula_example.rb](./malicious_formula_example.rb)**

Educational example demonstrating:
- Typosquatting techniques
- Post-install hooks
- Persistence mechanisms
- Credential harvesting
- C2 callbacks
- Detection indicators

#### Malicious Python Package
**[malicious_package_payload.py](./malicious_package_payload.py)**

Comprehensive payload example showing:
- Environmental reconnaissance
- Anti-sandbox techniques
- Credential harvesting
- Persistence (macOS/Linux/Windows)
- Data exfiltration methods
- Code obfuscation
- Detection indicators

#### OSINT Automation Framework
**[osint_automation.py](./osint_automation.py)**

Automated intelligence gathering tool demonstrating:
- Passive reconnaissance
- Active reconnaissance
- Social media intelligence
- Code repository analysis
- Package ecosystem profiling
- Complete OSINT toolkit reference

---

## 🎯 Quick Start

### Option 1: Read and Learn
```bash
# Read the main training document
cat OFFENSIVE_SECURITY_TRAINING.md

# Review example code
cat training_examples/malicious_package_payload.py

# Study OSINT techniques
python3 training_examples/osint_automation.py --toolkit
```

### Option 2: Set Up Training Lab
```bash
# Follow the lab setup guide
cat training_examples/LAB_SETUP_GUIDE.md

# Set up VMs and isolated network
# Install tools
# Run exercises in safe environment
```

### Option 3: Practice OSINT
```bash
# Run OSINT automation on your own systems
cd training_examples
python3 osint_automation.py localhost --output ./results

# Review findings and understand attack surface
```

---

## 📖 Learning Path

### Beginner Level
1. **Read:** OFFENSIVE_SECURITY_TRAINING.md (Sections 1-3)
2. **Understand:** Review example code with comments
3. **Practice:** Use OSINT tools on authorized targets
4. **Learn:** Study detection indicators

### Intermediate Level
1. **Set Up:** Create isolated training lab
2. **Deploy:** Run example payloads in controlled environment
3. **Observe:** Monitor detection tools
4. **Analyze:** Study C2 callbacks and persistence
5. **Document:** Create your own IOCs

### Advanced Level
1. **Modify:** Adapt examples to different scenarios
2. **Develop:** Create your own training scenarios
3. **Detect:** Build detection signatures
4. **Defend:** Implement countermeasures
5. **Test:** Practice incident response

---

## 🛠️ Tool Requirements

### Core Tools (OSINT)
```bash
# Network reconnaissance
- nmap
- masscan
- dnsenum

# Subdomain enumeration
- Amass
- Subfinder
- Assetfinder

# OSINT frameworks
- theHarvester
- Recon-ng
- SpiderFoot

# Code repository
- GitHub CLI (gh)
- TruffleHog
- GitLeaks
```

### Development Tools
```bash
# Package managers
- Homebrew
- pip/pip3
- npm
- gem

# Programming languages
- Python 3.8+
- Ruby 2.7+
- Node.js 16+
```

### Lab Environment
```bash
# Virtualization
- VirtualBox 7.0+ OR
- Docker 20.10+

# Operating systems
- Kali Linux (attacker)
- Ubuntu 22.04 (victim)
```

---

## 🎓 Training Exercises

### Exercise 1: OSINT Reconnaissance
**Objective:** Profile your own development environment

**Steps:**
1. Run OSINT automation on localhost
2. Enumerate installed packages
3. Identify exposed credentials
4. Map network services
5. Document findings

**Learning Goals:**
- Understand attacker reconnaissance
- Identify your attack surface
- Learn defensive hardening

### Exercise 2: Package Analysis
**Objective:** Identify malicious code patterns

**Steps:**
1. Review malicious_package_payload.py
2. Identify credential harvesting code
3. Find persistence mechanisms
4. Locate C2 callback functions
5. Document detection indicators

**Learning Goals:**
- Recognize malicious patterns
- Understand obfuscation techniques
- Develop code review skills

### Exercise 3: Isolated Payload Test
**Objective:** Test payload in safe environment

**Steps:**
1. Set up isolated lab (LAB_SETUP_GUIDE.md)
2. Deploy C2 server on attacker VM
3. Modify payload with correct C2 address
4. Install on victim VM
5. Monitor callbacks and persistence

**Learning Goals:**
- Understand complete attack chain
- Practice safe testing procedures
- Observe payload behavior

### Exercise 4: Detection Development
**Objective:** Create detection signatures

**Steps:**
1. Deploy monitoring tools (Osquery, auditd)
2. Run payload in monitored environment
3. Collect IOCs (network, file, process)
4. Create detection rules
5. Test detection effectiveness

**Learning Goals:**
- Build detection capabilities
- Understand blue team perspective
- Develop SIEM rules

### Exercise 5: Social Engineering Scenario
**Objective:** Design attack scenario

**Steps:**
1. Choose target profile (developer, sysadmin)
2. Conduct OSINT research
3. Design pretext and payload
4. Create malicious package
5. Document complete attack plan

**Learning Goals:**
- Understand social engineering
- Practice threat modeling
- Develop attacker mindset

---

## 🔍 What You'll Learn

### Offensive Techniques
- ✅ Social engineering methodology
- ✅ OSINT reconnaissance workflows
- ✅ Supply chain attack vectors
- ✅ Package exploitation techniques
- ✅ Persistence mechanisms
- ✅ Data exfiltration methods
- ✅ Obfuscation and evasion

### Defensive Techniques
- ✅ Attack detection indicators
- ✅ Monitoring and logging
- ✅ Package security best practices
- ✅ Network segmentation
- ✅ Endpoint protection
- ✅ Incident response procedures
- ✅ Threat hunting

### OSINT Skills
- ✅ Passive reconnaissance
- ✅ Active reconnaissance
- ✅ Social media intelligence
- ✅ Code repository analysis
- ✅ Technology stack profiling
- ✅ Credential discovery
- ✅ Infrastructure mapping

---

## 📊 Training Metrics

Track your progress:

```
[ ] Read complete training documentation
[ ] Set up isolated training lab
[ ] Completed Exercise 1: OSINT Reconnaissance
[ ] Completed Exercise 2: Package Analysis
[ ] Completed Exercise 3: Isolated Payload Test
[ ] Completed Exercise 4: Detection Development
[ ] Completed Exercise 5: Social Engineering Scenario
[ ] Created custom detection rules
[ ] Documented 10+ IOCs
[ ] Practiced incident response
[ ] Implemented defensive countermeasures
```

---

## 🔒 Security Best Practices

### For Training:
1. **Always use isolated environments**
   - No internet access for victim VMs
   - Separate network from production
   - Regular snapshots for clean state

2. **Never cross boundaries**
   - Don't test on others without permission
   - Don't deploy to real repositories
   - Keep malicious code in isolated environments

3. **Document everything**
   - Log all activities
   - Create IOC lists
   - Note defensive measures

4. **Think defensively**
   - How would you detect this?
   - What countermeasures exist?
   - How would you respond?

### For Real-World:
1. **Verify authorization**
   - Written permission for testing
   - Defined scope and boundaries
   - Clear rules of engagement

2. **Protect sensitive data**
   - Handle credentials securely
   - Encrypt sensitive findings
   - Follow disclosure policies

3. **Report responsibly**
   - Follow responsible disclosure
   - Document findings clearly
   - Provide remediation guidance

---

## 📚 Additional Resources

### Books
- "The Art of Deception" - Kevin Mitnick
- "The Hacker Playbook 3" - Peter Kim
- "Red Team Field Manual" - Ben Clark
- "Social Engineering: The Science of Human Hacking" - Christopher Hadnagy

### Courses
- Offensive Security OSCP
- SANS SEC560 (Network Penetration Testing)
- SANS FOR578 (Cyber Threat Intelligence)
- eLearnSecurity courses

### Platforms
- TryHackMe (beginner-friendly)
- HackTheBox (intermediate-advanced)
- PentesterLab (web security)
- RangeForce (enterprise scenarios)

### Frameworks
- MITRE ATT&CK: https://attack.mitre.org
- OWASP: https://owasp.org
- PTES: http://www.pentest-standard.org

### Communities
- r/netsec
- r/AskNetsec
- Hack The Box Discord
- OWASP Slack

---

## 🤝 Contributing

If you develop additional training materials:

1. **Ensure safety**
   - All code must be clearly marked as training
   - Include prominent warnings
   - Provide detection indicators

2. **Document thoroughly**
   - Explain techniques used
   - Provide defensive recommendations
   - Include references

3. **Maintain ethics**
   - Emphasize legal/ethical use
   - Include authorization requirements
   - Promote responsible disclosure

---

## ⚖️ Legal Notice

This repository contains educational security research materials. Users are responsible for:

1. **Compliance with Laws**
   - Computer Fraud and Abuse Act (CFAA)
   - Local and international hacking laws
   - Terms of service for all systems tested

2. **Authorization**
   - Only test systems you own or have explicit permission to test
   - Maintain documentation of authorization
   - Respect scope limitations

3. **Ethical Use**
   - Use for defensive security improvement
   - Report vulnerabilities responsibly
   - Don't harm others

**Disclaimer:** The authors assume no liability for misuse of these materials. Users are solely responsible for their actions.

---

## 📧 Questions?

For questions about:
- **Lab setup:** See LAB_SETUP_GUIDE.md troubleshooting section
- **Tools:** Check OSINT toolkit reference in osint_automation.py
- **Techniques:** Review OFFENSIVE_SECURITY_TRAINING.md
- **Ethics:** Always err on the side of caution and seek proper authorization

---

## 🎯 Final Thoughts

Remember:
- **Learn offense to build better defense**
- **Always maintain ethical boundaries**
- **Document and share knowledge responsibly**
- **Practice in safe, isolated environments**
- **Think like both attacker and defender**

The goal is not to become a better attacker, but to become a better defender by understanding the attacker's perspective.

**Stay curious. Stay ethical. Stay secure.** 🔒

---

*Last Updated: 2026-01-07*
*Version: 1.0*

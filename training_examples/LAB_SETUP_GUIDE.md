# Offensive Security Training Lab Setup Guide

This guide will help you set up a safe, isolated environment for practicing offensive security techniques, including social engineering, package exploitation, and OSINT.

---

## ⚠️ CRITICAL SAFETY WARNINGS

**Before You Begin:**
- ✅ Only practice on systems you own or have explicit permission to test
- ✅ Never deploy malicious packages to real package repositories
- ✅ Always use isolated environments (VMs, containers)
- ✅ Disconnect training environments from production networks
- ✅ Never test on others without written authorization
- ❌ Unauthorized testing is illegal and unethical

---

## Lab Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    HOST MACHINE                         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Virtualization Layer (VirtualBox/VMware) │   │
│  │                                                  │   │
│  │  ┌──────────────┐  ┌──────────────┐            │   │
│  │  │  Attacker VM │  │   Victim VM  │            │   │
│  │  │   (Kali)     │  │  (Ubuntu)    │            │   │
│  │  │              │  │              │            │   │
│  │  │  - OSINT     │  │  - Dev Env   │            │   │
│  │  │  - Tools     │  │  - Packages  │            │   │
│  │  │  - C2 Server │  │  - Services  │            │   │
│  │  └──────────────┘  └──────────────┘            │   │
│  │         │                   │                   │   │
│  │         └───────────────────┘                   │   │
│  │         Internal Network Only                   │   │
│  │         (No Internet Access)                    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: Virtual Machine Setup

### Option A: Using VirtualBox (Free)

#### 1. Install VirtualBox
```bash
# macOS
brew install --cask virtualbox

# Linux
sudo apt install virtualbox virtualbox-ext-pack

# Or download from: https://www.virtualbox.org/
```

#### 2. Create Attacker VM (Kali Linux)
```bash
# Download Kali Linux VirtualBox image
wget https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-virtualbox-amd64.7z

# Extract and import into VirtualBox
7z x kali-linux-2024.4-virtualbox-amd64.7z
# Import the .vbox file in VirtualBox
```

**VM Configuration:**
- RAM: 4GB minimum (8GB recommended)
- CPU: 2 cores minimum
- Disk: 40GB
- Network: Internal Network + NAT (for tool downloads)

#### 3. Create Victim VM (Ubuntu)
```bash
# Download Ubuntu Server/Desktop
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso

# Create new VM in VirtualBox and install Ubuntu
```

**VM Configuration:**
- RAM: 2GB minimum
- CPU: 2 cores
- Disk: 20GB
- Network: Internal Network only

### Option B: Using Docker (Lighter Alternative)

```bash
# Create isolated Docker network
docker network create --internal training-net

# Attacker container (Kali)
docker run -it --name attacker \
  --network training-net \
  kalilinux/kali-rolling

# Victim container (Ubuntu with dev tools)
docker run -it --name victim \
  --network training-net \
  ubuntu:22.04
```

---

## Phase 2: Attacker VM Setup (Kali Linux)

### 1. Initial System Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y \
  git curl wget vim tmux \
  python3 python3-pip \
  ruby-full golang-go
```

### 2. Install OSINT Tools

#### Network Reconnaissance
```bash
# Nmap (network scanner)
sudo apt install nmap -y

# Masscan (fast scanner)
sudo apt install masscan -y

# DNS tools
sudo apt install dnsutils fierce dnsenum dnsrecon -y
```

#### Subdomain Enumeration
```bash
# Amass
sudo apt install amass -y

# Subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Assetfinder
go install github.com/tomnomnom/assetfinder@latest
```

#### OSINT Frameworks
```bash
# theHarvester
sudo apt install theharvester -y

# Recon-ng
sudo apt install recon-ng -y

# SpiderFoot
pip3 install spiderfoot
```

#### Social Media OSINT
```bash
# Sherlock
git clone https://github.com/sherlock-project/sherlock.git
cd sherlock
pip3 install -r requirements.txt
```

#### Code Repository Tools
```bash
# GitHub CLI
sudo apt install gh -y

# TruffleHog
pip3 install truffleHog

# GitLeaks
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

#### Web Application Tools
```bash
# WhatWeb
sudo apt install whatweb -y

# WafW00f (WAF detection)
sudo apt install wafw00f -y

# Nikto (web scanner)
sudo apt install nikto -y
```

### 3. Install Social Engineering Tools

```bash
# Social Engineering Toolkit (SET)
sudo apt install set -y

# Gophish (phishing simulation)
wget https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip
unzip gophish-v0.12.1-linux-64bit.zip
cd gophish
chmod +x gophish
```

### 4. Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv ~/osint-env
source ~/osint-env/bin/activate

# Install Python OSINT libraries
pip install \
  requests beautifulsoup4 \
  shodan censys \
  python-whois dnspython \
  paramiko fabric \
  scapy pwntools
```

### 5. Set Up Local C2 Server (Training)

```bash
# Simple HTTP server for testing
mkdir ~/c2-server
cd ~/c2-server

# Create simple callback receiver
cat > server.py << 'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime

class CallbackHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length)

        print(f"\n[{datetime.now()}] Callback received:")
        print(f"From: {self.client_address[0]}")
        print(f"Data: {body.decode()}\n")

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), CallbackHandler)
    print("[*] C2 server listening on port 8080...")
    server.serve_forever()
EOF

# Run server
python3 server.py
```

---

## Phase 3: Victim VM Setup (Ubuntu)

### 1. Initial System Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install development tools
sudo apt install -y \
  build-essential \
  git curl wget vim \
  python3 python3-pip \
  nodejs npm \
  ruby ruby-dev \
  golang-go
```

### 2. Install Package Managers

```bash
# NPM (Node Package Manager)
sudo npm install -g npm@latest

# Python pip
sudo apt install python3-pip -y

# Ruby gems
sudo apt install ruby-full -y

# Homebrew (Linux)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Set Up Developer Environment

```bash
# Create realistic developer directory structure
mkdir -p ~/projects/{project1,project2,internal-tools}

# Create sample configuration files
cat > ~/.gitconfig << EOF
[user]
    name = Test Developer
    email = developer@example.com
[core]
    editor = vim
EOF

# Create sample AWS credentials (fake)
mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

# Create sample SSH keys (for testing only)
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""

# Create sample .env file
cat > ~/projects/project1/.env << EOF
DATABASE_URL=postgresql://user:password@localhost/db
API_KEY=sk-test1234567890abcdefghijklmnop
SECRET_TOKEN=super_secret_token_12345
EOF
```

### 4. Install Monitoring Tools (for detection practice)

```bash
# Osquery (endpoint visibility)
wget https://pkg.osquery.io/deb/osquery_5.10.2-1.linux_amd64.deb
sudo dpkg -i osquery_5.10.2-1.linux_amd64.deb

# Auditd (system auditing)
sudo apt install auditd audispd-plugins -y

# Process monitoring
sudo apt install sysstat -y
```

---

## Phase 4: Network Configuration

### 1. Set Up Internal Network (VirtualBox)

```bash
# On Host Machine
# Configure internal network in VirtualBox:
# - Attacker VM: Network Adapter 1 = Internal Network "training-net"
# - Victim VM: Network Adapter 1 = Internal Network "training-net"

# Configure static IPs:
# Attacker VM: 192.168.100.10
# Victim VM: 192.168.100.20
```

### 2. Configure Attacker VM Network

```bash
# Edit network configuration
sudo nano /etc/network/interfaces

# Add:
auto eth0
iface eth0 inet static
    address 192.168.100.10
    netmask 255.255.255.0

# Restart networking
sudo systemctl restart networking
```

### 3. Configure Victim VM Network

```bash
# Edit network configuration
sudo nano /etc/network/interfaces

# Add:
auto eth0
iface eth0 inet static
    address 192.168.100.20
    netmask 255.255.255.0

# Restart networking
sudo systemctl restart networking
```

### 4. Verify Connectivity

```bash
# From Attacker VM
ping 192.168.100.20

# From Victim VM
ping 192.168.100.10
```

---

## Phase 5: Training Exercises Setup

### Exercise 1: OSINT Reconnaissance

```bash
# On Attacker VM
cd ~/
git clone <this-training-repo>
cd training_examples

# Run OSINT framework
python3 osint_automation.py --toolkit

# Practice on victim VM
python3 osint_automation.py 192.168.100.20
```

### Exercise 2: Malicious Package Creation

```bash
# On Attacker VM
cd ~/training_examples

# Review example malicious formula
cat malicious_formula_example.rb

# Review example Python payload
cat malicious_package_payload.py

# Modify C2 server address to point to your local server
# Change: https://attacker.example.com
# To: http://192.168.100.10:8080
```

### Exercise 3: Package Deployment Test

```bash
# On Attacker VM - Start C2 server
cd ~/c2-server
python3 server.py

# On Victim VM - Install test package
cd ~/
# Copy modified training package
python3 -m pip install ./malicious_package_test

# Observe callback on Attacker VM C2 server
```

### Exercise 4: Detection Practice

```bash
# On Victim VM - Monitor for suspicious activity

# Watch process creation
sudo auditctl -w /usr/bin/python3 -p x -k python_exec

# Monitor network connections
sudo tcpdump -i eth0 -n

# Query with Osquery
osqueryi
> SELECT * FROM processes WHERE name LIKE '%python%';
> SELECT * FROM listening_ports;

# Check for persistence mechanisms
ls -la ~/Library/LaunchAgents/  # macOS
ls -la ~/.config/systemd/user/  # Linux
crontab -l
```

---

## Phase 6: Safe Testing Procedures

### Snapshot Management

```bash
# Always create VM snapshots before testing
# VirtualBox: Machine > Take Snapshot
# Name: "Clean State - YYYYMMDD"

# After each exercise, restore to clean state
# VirtualBox: Machine > Restore Snapshot
```

### Network Isolation Verification

```bash
# Verify no internet access from internal network
# On Victim VM
ping 8.8.8.8  # Should fail
curl https://google.com  # Should fail

# On Attacker VM (if NAT adapter enabled)
# Disable when running exercises:
sudo ifconfig eth1 down  # Disable NAT adapter
```

### Clean Up After Exercises

```bash
# On Victim VM after each exercise

# Remove persistence mechanisms
rm -rf ~/Library/LaunchAgents/com.malicious.*
crontab -r
sudo systemctl list-units --type=service | grep malicious

# Clear logs
sudo truncate -s 0 /var/log/syslog
sudo truncate -s 0 /var/log/auth.log

# Remove test files
rm -rf /tmp/.*recon*
rm -rf ~/.test-*

# Restore snapshot to clean state
```

---

## Phase 7: Advanced Lab Enhancements

### 1. Add Web Application Target

```bash
# On Victim VM - Install vulnerable web app
docker run -d -p 80:80 vulnerables/web-dvwa

# Access from Attacker VM
firefox http://192.168.100.20
```

### 2. Add Git Server (for code repo testing)

```bash
# On Victim VM - Install Gitea
docker run -d --name gitea -p 3000:3000 gitea/gitea:latest

# Access from Attacker VM
firefox http://192.168.100.20:3000
```

### 3. Add Package Registry (for supply chain testing)

```bash
# On Victim VM - Install local PyPI server
pip3 install pypiserver
mkdir ~/pypi-packages
pypi-server -p 8080 ~/pypi-packages

# On Attacker VM - Upload malicious package
python3 setup.py sdist
twine upload --repository-url http://192.168.100.20:8080 dist/*
```

### 4. Add Logging and Monitoring Dashboard

```bash
# On Victim VM - Install ELK stack
docker-compose up -d elasticsearch kibana filebeat

# Configure log shipping
# View logs in Kibana: http://192.168.100.20:5601
```

---

## Phase 8: Training Documentation

### Log Your Activities

```bash
# Create training log directory
mkdir ~/training-logs

# Log each exercise
cat > ~/training-logs/exercise-1.md << EOF
# Exercise 1: OSINT Reconnaissance

## Date: $(date)

## Objective:
Enumerate victim system using OSINT techniques

## Steps Taken:
1. Port scan with nmap
2. Service enumeration
3. Subdomain discovery

## Findings:
- Open ports: 22, 80, 443
- Services: SSH, HTTP, HTTPS
- Subdomains: dev.target.com, api.target.com

## Defensive Recommendations:
- Close unnecessary ports
- Update SSH configuration
- Implement rate limiting

## References:
- [MITRE ATT&CK T1595](https://attack.mitre.org/techniques/T1595/)
EOF
```

### Create Detection Signatures

```bash
# Document IOCs from each exercise
cat > ~/training-logs/iocs.txt << EOF
# Indicators of Compromise

## Network
- Connections to 192.168.100.10:8080
- DNS queries to attacker.example.com
- Unusual user agent strings

## File System
- /tmp/.recon
- ~/Library/LaunchAgents/com.malicious.*
- ~/.bashrc modifications

## Process
- Python execution during package install
- Curl/wget during unexpected times
- Base64 encoded commands
EOF
```

---

## Troubleshooting

### Issue: VMs can't communicate
```bash
# Check network adapter settings
# Ensure both VMs on same internal network
# Verify static IP configuration
ip addr show

# Test connectivity
ping -c 4 192.168.100.20
```

### Issue: Tools not installing
```bash
# Update package lists
sudo apt update

# Install dependencies
sudo apt install build-essential -y

# Use Python virtual environments
python3 -m venv venv
source venv/bin/activate
```

### Issue: Permissions errors
```bash
# Add user to necessary groups
sudo usermod -aG docker $USER
sudo usermod -aG sudo $USER

# Reload groups
newgrp docker
```

---

## Additional Resources

### Books
- "The Hacker Playbook 3" - Peter Kim
- "Red Team Field Manual" - Ben Clark
- "Social Engineering: The Science of Human Hacking" - Christopher Hadnagy

### Online Platforms
- TryHackMe: https://tryhackme.com
- HackTheBox: https://hackthebox.com
- PentesterLab: https://pentesterlab.com

### CTF Platforms
- PicoCTF: https://picoctf.org
- OverTheWire: https://overthewire.org
- CTFtime: https://ctftime.org

### Documentation
- MITRE ATT&CK: https://attack.mitre.org
- OWASP: https://owasp.org
- NIST Cybersecurity: https://www.nist.gov/cyberframework

---

## Legal and Ethical Reminders

⚠️ **CRITICAL:**
- Only test in your isolated lab environment
- Never deploy malicious packages to real repositories
- Don't use techniques learned here for unauthorized access
- Maintain ethical boundaries at all times
- Document authorization for any testing outside your lab
- Report vulnerabilities responsibly

---

## Conclusion

You now have a complete offensive security training lab for learning:
- Social engineering techniques
- Package exploitation and supply chain attacks
- OSINT reconnaissance
- Detection and defensive techniques

**Remember:** The goal is to learn both offensive and defensive security. Always think about how attacks can be detected and prevented.

**Next Steps:**
1. Complete Exercise 1-4 from the training guide
2. Document your findings
3. Develop detection signatures
4. Create defensive countermeasures
5. Practice incident response

Happy learning! 🎯🔒

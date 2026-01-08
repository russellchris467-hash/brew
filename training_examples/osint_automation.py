#!/usr/bin/env python3
"""
OSINT Automation Framework for Security Training
Demonstrates automated intelligence gathering techniques
"""

import os
import sys
import json
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime


class OSINTFramework:
    """
    Educational OSINT automation framework
    Demonstrates reconnaissance techniques for security training
    """

    def __init__(self, target: str, output_dir: str = "./osint_results"):
        self.target = target
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.results = {}

    def run_full_recon(self):
        """Execute complete OSINT reconnaissance"""

        print("[*] Starting OSINT reconnaissance...")
        print(f"[*] Target: {self.target}")
        print(f"[*] Output: {self.output_dir}")
        print("-" * 60)

        # Phase 1: Passive reconnaissance
        print("\n[Phase 1] Passive Reconnaissance")
        self.results['passive'] = self._passive_recon()

        # Phase 2: Active reconnaissance
        print("\n[Phase 2] Active Reconnaissance")
        self.results['active'] = self._active_recon()

        # Phase 3: Social media & people
        print("\n[Phase 3] Social Media Intelligence")
        self.results['social'] = self._social_recon()

        # Phase 4: Code repositories
        print("\n[Phase 4] Code Repository Analysis")
        self.results['code'] = self._code_recon()

        # Phase 5: Package ecosystem analysis
        print("\n[Phase 5] Package Ecosystem Analysis")
        self.results['packages'] = self._package_recon()

        # Save results
        self._save_results()

        print(f"\n[✓] Reconnaissance complete!")
        print(f"[✓] Results saved to: {self.output_dir}")

        return self.results

    def _passive_recon(self) -> Dict:
        """Passive reconnaissance (no direct target interaction)"""

        results = {}

        # 1. Domain information
        print("  [→] Gathering domain information...")
        results['whois'] = self._whois_lookup()
        results['dns'] = self._dns_enumeration()
        results['subdomains'] = self._subdomain_enumeration()

        # 2. Certificate transparency
        print("  [→] Checking certificate transparency logs...")
        results['certificates'] = self._cert_transparency()

        # 3. Search engine reconnaissance
        print("  [→] Search engine reconnaissance...")
        results['search_engines'] = self._search_engine_recon()

        # 4. Shodan/Censys (Internet-wide scan data)
        print("  [→] Checking internet scan databases...")
        results['shodan'] = self._shodan_lookup()

        return results

    def _active_recon(self) -> Dict:
        """Active reconnaissance (direct target interaction)"""

        results = {}

        # 1. Port scanning
        print("  [→] Port scanning...")
        results['ports'] = self._port_scan()

        # 2. Service enumeration
        print("  [→] Service enumeration...")
        results['services'] = self._service_enumeration()

        # 3. Web application fingerprinting
        print("  [→] Web application fingerprinting...")
        results['webapp'] = self._webapp_fingerprint()

        # 4. Technology stack detection
        print("  [→] Technology stack detection...")
        results['tech_stack'] = self._detect_tech_stack()

        return results

    def _social_recon(self) -> Dict:
        """Social media and people intelligence"""

        results = {}

        # 1. LinkedIn enumeration
        print("  [→] LinkedIn reconnaissance...")
        results['linkedin'] = self._linkedin_recon()

        # 2. GitHub/GitLab users
        print("  [→] GitHub/GitLab user enumeration...")
        results['github'] = self._github_recon()

        # 3. Email harvesting
        print("  [→] Email address harvesting...")
        results['emails'] = self._email_harvesting()

        # 4. Social media profiles
        print("  [→] Social media profile discovery...")
        results['social_profiles'] = self._social_profile_search()

        return results

    def _code_recon(self) -> Dict:
        """Code repository analysis"""

        results = {}

        # 1. GitHub organization analysis
        print("  [→] Analyzing GitHub organization...")
        results['github_org'] = self._analyze_github_org()

        # 2. Repository enumeration
        print("  [→] Enumerating repositories...")
        results['repositories'] = self._enumerate_repositories()

        # 3. Dependency analysis
        print("  [→] Analyzing dependencies...")
        results['dependencies'] = self._analyze_dependencies()

        # 4. Secret scanning
        print("  [→] Scanning for exposed secrets...")
        results['secrets'] = self._scan_for_secrets()

        # 5. Commit analysis
        print("  [→] Analyzing commit history...")
        results['commits'] = self._analyze_commits()

        return results

    def _package_recon(self) -> Dict:
        """Package ecosystem reconnaissance"""

        results = {}

        # 1. NPM packages
        print("  [→] Searching NPM registry...")
        results['npm'] = self._npm_package_search()

        # 2. PyPI packages
        print("  [→] Searching PyPI registry...")
        results['pypi'] = self._pypi_package_search()

        # 3. RubyGems packages
        print("  [→] Searching RubyGems registry...")
        results['rubygems'] = self._rubygems_package_search()

        # 4. Homebrew formulae
        print("  [→] Searching Homebrew registry...")
        results['homebrew'] = self._homebrew_package_search()

        return results

    # Implementation methods for each technique

    def _whois_lookup(self) -> Dict:
        """WHOIS domain lookup"""
        try:
            result = self._run_command(['whois', self.target])
            return {'raw': result, 'status': 'success'}
        except:
            return {'status': 'failed', 'note': 'whois command not available'}

    def _dns_enumeration(self) -> Dict:
        """DNS record enumeration"""
        records = {}
        record_types = ['A', 'AAAA', 'MX', 'NS', 'TXT', 'SOA']

        for rtype in record_types:
            try:
                result = self._run_command(['dig', '+short', self.target, rtype])
                if result:
                    records[rtype] = result.strip().split('\n')
            except:
                pass

        return records

    def _subdomain_enumeration(self) -> List[str]:
        """
        Subdomain enumeration
        Tools: Amass, Subfinder, Assetfinder, etc.
        """
        subdomains = []

        # Method 1: Certificate transparency (crt.sh)
        # Query: https://crt.sh/?q=%.target.com&output=json

        # Method 2: DNS bruteforce with common subdomains
        common_subs = [
            'www', 'mail', 'ftp', 'admin', 'portal', 'api',
            'dev', 'staging', 'test', 'vpn', 'git', 'jenkins'
        ]

        for sub in common_subs:
            domain = f"{sub}.{self.target}"
            try:
                result = self._run_command(['dig', '+short', domain, 'A'])
                if result and result.strip():
                    subdomains.append(domain)
            except:
                pass

        # Method 3: Using subfinder (if installed)
        try:
            result = self._run_command(['subfinder', '-d', self.target, '-silent'])
            if result:
                subdomains.extend(result.strip().split('\n'))
        except:
            pass

        return list(set(subdomains))

    def _cert_transparency(self) -> Dict:
        """Certificate transparency log search"""
        # Query crt.sh for certificates
        # API: https://crt.sh/?q=%.example.com&output=json
        return {'note': 'Query crt.sh API for certificate transparency logs'}

    def _search_engine_recon(self) -> Dict:
        """
        Search engine reconnaissance (Google Dorking)
        Educational: Common Google dorks for reconnaissance
        """
        dorks = {
            'subdomains': f'site:{self.target}',
            'files': f'site:{self.target} filetype:pdf OR filetype:doc OR filetype:xls',
            'login_pages': f'site:{self.target} inurl:login OR inurl:signin OR inurl:admin',
            'exposed_files': f'site:{self.target} filetype:env OR filetype:config',
            'employee_info': f'site:linkedin.com "{self.target}"',
            'github_repos': f'site:github.com "{self.target}"',
            'pastebin_leaks': f'site:pastebin.com "{self.target}"',
        }

        return {'dorks': dorks, 'note': 'Use these dorks manually in search engines'}

    def _shodan_lookup(self) -> Dict:
        """
        Shodan/Censys lookup
        Educational: Requires API key
        """
        # Command: shodan host <IP>
        # API: https://api.shodan.io/shodan/host/{ip}?key={API_KEY}
        return {'note': 'Use Shodan CLI or API with valid API key'}

    def _port_scan(self) -> Dict:
        """
        Port scanning with nmap
        Educational: Common port scanning techniques
        """

        # Basic scan (requires root for SYN scan)
        try:
            result = self._run_command([
                'nmap', '-Pn', '-p-', '--top-ports', '1000',
                '-T4', '--open', self.target
            ])
            return {'scan_result': result, 'status': 'success'}
        except:
            return {'status': 'failed', 'note': 'nmap not available or insufficient permissions'}

    def _service_enumeration(self) -> Dict:
        """Service version detection"""
        # nmap -sV -sC for service/version detection and default scripts
        return {'note': 'Run: nmap -sV -sC -p <ports> <target>'}

    def _webapp_fingerprint(self) -> Dict:
        """Web application fingerprinting"""
        # Tools: Wappalyzer, WhatWeb, BuiltWith
        try:
            result = self._run_command(['whatweb', self.target])
            return {'result': result}
        except:
            return {'note': 'Install whatweb for web technology detection'}

    def _detect_tech_stack(self) -> Dict:
        """Detect technology stack"""
        indicators = {
            'server_headers': self._check_server_headers(),
            'cookies': self._analyze_cookies(),
            'meta_tags': self._parse_meta_tags(),
        }
        return indicators

    def _check_server_headers(self) -> Dict:
        """Check HTTP headers for technology indicators"""
        try:
            result = self._run_command(['curl', '-I', f'https://{self.target}'])
            return {'headers': result}
        except:
            return {}

    def _analyze_cookies(self) -> Dict:
        """Analyze cookies for framework detection"""
        # JSESSIONID = Java
        # PHPSESSID = PHP
        # ASP.NET_SessionId = ASP.NET
        return {'note': 'Analyze cookies from HTTP response'}

    def _parse_meta_tags(self) -> Dict:
        """Parse HTML meta tags"""
        return {'note': 'Parse <meta> tags from HTML'}

    def _linkedin_recon(self) -> Dict:
        """
        LinkedIn reconnaissance
        Educational: Employee enumeration for social engineering
        """
        techniques = {
            'search': f'site:linkedin.com "{self.target}"',
            'employee_count': 'Check company page for employee count',
            'job_titles': 'Enumerate common job titles',
            'technologies': 'Job postings reveal tech stack',
        }
        return techniques

    def _github_recon(self) -> Dict:
        """GitHub reconnaissance"""
        try:
            # Check if organization exists
            result = self._run_command(['gh', 'api', f'/orgs/{self.target}'])
            return {'org_info': result}
        except:
            return {'note': 'Install GitHub CLI (gh) for automated queries'}

    def _email_harvesting(self) -> List[str]:
        """
        Email harvesting
        Tools: theHarvester, hunter.io
        """
        emails = []

        # Using theHarvester
        try:
            result = self._run_command([
                'theHarvester', '-d', self.target, '-b', 'all', '-l', '500'
            ])
            # Parse email addresses from result
            # emails.extend(parsed_emails)
        except:
            pass

        return emails

    def _social_profile_search(self) -> Dict:
        """
        Social media profile discovery
        Tools: Sherlock, WhatsMyName
        """
        return {'note': 'Use Sherlock to find usernames across social media platforms'}

    def _analyze_github_org(self) -> Dict:
        """Analyze GitHub organization"""
        try:
            # Get organization info
            org_info = self._run_command(['gh', 'api', f'/orgs/{self.target}'])

            # Get members
            members = self._run_command(['gh', 'api', f'/orgs/{self.target}/members'])

            return {'org': org_info, 'members': members}
        except:
            return {}

    def _enumerate_repositories(self) -> List[str]:
        """Enumerate GitHub repositories"""
        try:
            result = self._run_command([
                'gh', 'repo', 'list', self.target, '--limit', '1000', '--json', 'name'
            ])
            return json.loads(result) if result else []
        except:
            return []

    def _analyze_dependencies(self) -> Dict:
        """
        Analyze dependencies in repositories
        Look for: package.json, requirements.txt, Gemfile, go.mod
        """
        dependencies = {
            'npm': [],
            'pip': [],
            'ruby': [],
            'go': [],
            'homebrew': [],
        }

        # This would clone repos and analyze dependency files
        return dependencies

    def _scan_for_secrets(self) -> Dict:
        """
        Scan for exposed secrets in repositories
        Tools: TruffleHog, GitLeaks, GitRob
        """

        findings = []

        # Using TruffleHog
        try:
            # trufflehog github --org=<target>
            pass
        except:
            pass

        return {'note': 'Use TruffleHog or GitLeaks to scan for secrets'}

    def _analyze_commits(self) -> Dict:
        """Analyze commit history for sensitive information"""
        return {
            'note': 'Look for: API keys, passwords, internal URLs, employee names'
        }

    def _npm_package_search(self) -> List[str]:
        """Search NPM registry for organization packages"""
        try:
            result = self._run_command(['npm', 'search', self.target])
            return result.split('\n') if result else []
        except:
            return []

    def _pypi_package_search(self) -> List[str]:
        """Search PyPI for organization packages"""
        # Use PyPI API: https://pypi.org/search/?q=<target>
        return []

    def _rubygems_package_search(self) -> List[str]:
        """Search RubyGems for organization packages"""
        try:
            result = self._run_command(['gem', 'search', '-r', self.target])
            return result.split('\n') if result else []
        except:
            return []

    def _homebrew_package_search(self) -> List[str]:
        """Search Homebrew for organization packages"""
        try:
            result = self._run_command(['brew', 'search', self.target])
            return result.split('\n') if result else []
        except:
            return []

    def _run_command(self, cmd: List[str], timeout: int = 30) -> Optional[str]:
        """Execute command and return output"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.stdout
        except Exception as e:
            print(f"    [!] Command failed: {' '.join(cmd)}")
            return None

    def _save_results(self):
        """Save results to JSON file"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = self.output_dir / f"osint_{self.target}_{timestamp}.json"

        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

        print(f"\n[*] Results saved to: {filename}")


class OSINTToolkit:
    """
    Educational reference for OSINT tools
    """

    TOOLS = {
        'Network Reconnaissance': [
            'nmap - Network scanner',
            'masscan - Fast port scanner',
            'zmap - Internet-wide scanner',
            'dnsenum - DNS enumeration',
            'fierce - DNS scanner',
            'dnsrecon - DNS reconnaissance',
        ],

        'Subdomain Enumeration': [
            'Amass - Comprehensive subdomain discovery',
            'Subfinder - Fast subdomain discovery',
            'Assetfinder - Find domains and subdomains',
            'Findomain - Fast subdomain enumerator',
            'Sublist3r - Python tool for subdomain enum',
        ],

        'OSINT Frameworks': [
            'theHarvester - Email, domain, IP harvester',
            'Maltego - Visual link analysis',
            'Recon-ng - Full-featured reconnaissance framework',
            'SpiderFoot - Automated OSINT',
            'OSINT Framework - Directory of OSINT tools',
        ],

        'Social Media': [
            'Sherlock - Username search across social media',
            'Social-Analyzer - Social media profile analyzer',
            'Twint - Twitter intelligence tool',
        ],

        'Code Repository': [
            'GitRob - GitHub organization analyzer',
            'TruffleHog - Search for secrets in Git repos',
            'GitLeaks - Scan for secrets',
            'Gitrob - GitHub reconnaissance',
            'GitDorker - GitHub dork scanning',
        ],

        'Web Application': [
            'WhatWeb - Web application identifier',
            'Wappalyzer - Technology profiler',
            'BuiltWith - Technology lookup',
            'Shodan - Internet-connected device search',
            'Censys - Internet scan data',
        ],
    }

    @classmethod
    def print_toolkit(cls):
        """Print available OSINT tools"""
        print("\n" + "="*60)
        print("OSINT TOOLKIT REFERENCE")
        print("="*60 + "\n")

        for category, tools in cls.TOOLS.items():
            print(f"\n{category}:")
            print("-" * 40)
            for tool in tools:
                print(f"  • {tool}")

        print("\n" + "="*60 + "\n")


def main():
    """Main entry point"""

    parser = argparse.ArgumentParser(
        description='OSINT Automation Framework for Security Training'
    )
    parser.add_argument('target', help='Target domain or organization')
    parser.add_argument('--output', '-o', default='./osint_results',
                        help='Output directory for results')
    parser.add_argument('--toolkit', action='store_true',
                        help='Print OSINT toolkit reference')

    args = parser.parse_args()

    if args.toolkit:
        OSINTToolkit.print_toolkit()
        return

    print("\n" + "="*60)
    print("OSINT AUTOMATION FRAMEWORK")
    print("Educational Tool for Security Training")
    print("="*60 + "\n")

    print("⚠️  WARNING: Only use on authorized targets")
    print("⚠️  Unauthorized reconnaissance may be illegal\n")

    response = input("Do you have authorization to scan this target? (yes/no): ")
    if response.lower() != 'yes':
        print("\n[!] Exiting. Only scan authorized targets.")
        return

    # Run OSINT reconnaissance
    osint = OSINTFramework(args.target, args.output)
    osint.run_full_recon()


if __name__ == '__main__':
    main()

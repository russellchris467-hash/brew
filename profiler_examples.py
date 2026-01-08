#!/usr/bin/env python3
"""
Pentesting Profiler - Usage Examples
Demonstrates how to use the profiler programmatically
"""

import sys
import json
from pathlib import Path

# Add parent directory to path if needed
sys.path.insert(0, str(Path(__file__).parent))

# Note: In production, you would import from installed package
# from pentest_profiler import PentestProfiler


def example_basic_scan():
    """
    Example 1: Basic scan with default settings
    """
    print("=" * 70)
    print("EXAMPLE 1: Basic Scan")
    print("=" * 70)

    from pentest_profiler import PentestProfiler

    # Create profiler instance
    profiler = PentestProfiler(
        target='example.com',
        output_dir='./example1_results'
    )

    # Run full profile
    profiler.run_full_profile()

    print("\n✓ Results saved to: ./example1_results")


def example_aggressive_scan():
    """
    Example 2: Aggressive scan with custom threads
    """
    print("=" * 70)
    print("EXAMPLE 2: Aggressive Scan")
    print("=" * 70)

    from pentest_profiler import PentestProfiler

    # Create profiler with aggressive mode
    profiler = PentestProfiler(
        target='target.com',
        output_dir='./example2_results',
        threads=20,
        aggressive=True
    )

    # Run full profile
    profiler.run_full_profile()

    print("\n✓ Aggressive scan complete")


def example_custom_workflow():
    """
    Example 3: Custom workflow - run specific phases only
    """
    print("=" * 70)
    print("EXAMPLE 3: Custom Workflow")
    print("=" * 70)

    from pentest_profiler import PentestProfiler

    profiler = PentestProfiler(
        target='webapp.example.com',
        output_dir='./example3_results'
    )

    # Run only specific phases
    print("\n[Phase 1] Network reconnaissance...")
    profiler.network_recon()

    print("\n[Phase 2] Web profiling...")
    profiler.web_profiling()

    print("\n[Phase 3] Generating report...")
    profiler.generate_report()

    print("\n✓ Custom workflow complete")


def example_parse_results():
    """
    Example 4: Parse and analyze results
    """
    print("=" * 70)
    print("EXAMPLE 4: Parse Results")
    print("=" * 70)

    # Find most recent JSON report
    results_dir = Path('./pentest_results')

    if not results_dir.exists():
        print("No results directory found")
        return

    json_files = list(results_dir.glob('report_*.json'))

    if not json_files:
        print("No JSON reports found")
        return

    # Load most recent report
    latest_report = max(json_files, key=lambda p: p.stat().st_mtime)
    print(f"Loading: {latest_report}")

    with open(latest_report, 'r') as f:
        results = json.load(f)

    # Analyze results
    print("\n" + "=" * 70)
    print("ANALYSIS")
    print("=" * 70)

    # Target info
    print(f"\nTarget: {results['target']}")
    print(f"Scan Date: {results['timestamp']}")
    print(f"Scan Type: {results['scan_type']}")

    # Open ports
    open_ports = results['network'].get('ports', {}).get('open_ports', [])
    print(f"\nOpen Ports: {len(open_ports)}")
    for port in open_ports[:5]:  # Show first 5
        print(f"  - {port['port']}/{port['protocol']} ({port['service']})")

    # Web services
    web_services = results.get('web', {})
    print(f"\nWeb Services: {len(web_services)}")
    for port, info in list(web_services.items())[:3]:  # Show first 3
        print(f"  - Port {port}: {info.get('url', 'N/A')}")
        print(f"    Technologies: {', '.join(info.get('technologies', []))}")

    # Vulnerabilities
    vulns = results.get('vulnerabilities', [])
    print(f"\nVulnerabilities: {len(vulns)}")

    # Count by severity
    severity_counts = {}
    for vuln in vulns:
        severity = vuln['severity']
        severity_counts[severity] = severity_counts.get(severity, 0) + 1

    for severity, count in sorted(severity_counts.items()):
        print(f"  - {severity}: {count}")

    # Show high severity vulnerabilities
    high_vulns = [v for v in vulns if v['severity'] == 'HIGH']
    if high_vulns:
        print("\nHigh Severity Vulnerabilities:")
        for vuln in high_vulns:
            print(f"  - {vuln['type']}: {vuln['description']}")

    # Users
    users = results.get('users', [])
    print(f"\nDiscovered Users: {len(users)}")
    for user in users[:5]:  # Show first 5
        print(f"  - {user}")


def example_batch_scan():
    """
    Example 5: Batch scanning multiple targets
    """
    print("=" * 70)
    print("EXAMPLE 5: Batch Scan")
    print("=" * 70)

    from pentest_profiler import PentestProfiler

    # List of targets (replace with actual authorized targets)
    targets = [
        'target1.example.com',
        'target2.example.com',
        'target3.example.com'
    ]

    for target in targets:
        print(f"\n{'=' * 70}")
        print(f"Scanning: {target}")
        print('=' * 70)

        try:
            profiler = PentestProfiler(
                target=target,
                output_dir=f'./batch_results/{target.replace(".", "_")}'
            )

            profiler.run_full_profile()
            print(f"✓ {target} scan complete")

        except Exception as e:
            print(f"✗ {target} scan failed: {str(e)}")
            continue

    print("\n✓ Batch scan complete")


def example_continuous_monitoring():
    """
    Example 6: Continuous monitoring - scheduled scanning
    """
    print("=" * 70)
    print("EXAMPLE 6: Continuous Monitoring")
    print("=" * 70)

    from pentest_profiler import PentestProfiler
    import time
    from datetime import datetime

    target = 'monitor.example.com'
    scan_interval = 3600  # 1 hour in seconds

    print(f"Monitoring {target}")
    print(f"Scan interval: {scan_interval} seconds")
    print("Press Ctrl+C to stop\n")

    scan_count = 0

    try:
        while True:
            scan_count += 1
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            print(f"\n[Scan #{scan_count}] {timestamp}")
            print("-" * 70)

            profiler = PentestProfiler(
                target=target,
                output_dir=f'./monitoring/{datetime.now().strftime("%Y%m%d")}'
            )

            profiler.run_full_profile()

            # Compare with previous scan
            # (In production, implement change detection)

            print(f"\n✓ Scan #{scan_count} complete")
            print(f"Next scan in {scan_interval} seconds...")

            time.sleep(scan_interval)

    except KeyboardInterrupt:
        print("\n\n✓ Monitoring stopped")
        print(f"Total scans completed: {scan_count}")


def example_export_to_csv():
    """
    Example 7: Export results to CSV
    """
    print("=" * 70)
    print("EXAMPLE 7: Export to CSV")
    print("=" * 70)

    import csv
    from pathlib import Path

    # Find most recent JSON report
    results_dir = Path('./pentest_results')
    json_files = list(results_dir.glob('report_*.json'))

    if not json_files:
        print("No JSON reports found")
        return

    latest_report = max(json_files, key=lambda p: p.stat().st_mtime)

    with open(latest_report, 'r') as f:
        results = json.load(f)

    # Export vulnerabilities to CSV
    csv_file = results_dir / 'vulnerabilities.csv'

    with open(csv_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Type', 'Severity', 'Description', 'Recommendation'])

        for vuln in results.get('vulnerabilities', []):
            writer.writerow([
                vuln['type'],
                vuln['severity'],
                vuln['description'],
                vuln['recommendation']
            ])

    print(f"✓ Vulnerabilities exported to: {csv_file}")

    # Export open ports to CSV
    ports_csv = results_dir / 'open_ports.csv'

    with open(ports_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Port', 'Protocol', 'Service'])

        for port in results['network'].get('ports', {}).get('open_ports', []):
            writer.writerow([
                port['port'],
                port['protocol'],
                port['service']
            ])

    print(f"✓ Open ports exported to: {ports_csv}")


def example_integration_with_tools():
    """
    Example 8: Integration with other security tools
    """
    print("=" * 70)
    print("EXAMPLE 8: Tool Integration")
    print("=" * 70)

    from pentest_profiler import PentestProfiler
    import json

    # Run scan
    profiler = PentestProfiler(
        target='integration.example.com',
        output_dir='./integration_results'
    )

    profiler.run_full_profile()

    # Load results
    results_dir = Path('./integration_results')
    json_files = list(results_dir.glob('report_*.json'))
    latest_report = max(json_files, key=lambda p: p.stat().st_mtime)

    with open(latest_report, 'r') as f:
        results = json.load(f)

    # Generate Nmap XML format for import into other tools
    # (Simplified example - in production, generate valid XML)
    open_ports = results['network'].get('ports', {}).get('open_ports', [])

    nmap_output = f"""<?xml version="1.0"?>
<nmaprun>
  <host>
    <address addr="{results['network']['dns'].get('ip_address', 'N/A')}" />
    <ports>
"""

    for port in open_ports:
        nmap_output += f"""      <port protocol="{port['protocol']}" portid="{port['port']}">
        <state state="open" />
        <service name="{port['service']}" />
      </port>
"""

    nmap_output += """    </ports>
  </host>
</nmaprun>
"""

    # Save nmap-compatible output
    nmap_file = results_dir / 'nmap_import.xml'
    with open(nmap_file, 'w') as f:
        f.write(nmap_output)

    print(f"✓ Nmap-compatible output: {nmap_file}")
    print("  Import this into Metasploit, Burp Suite, or other tools")


# Menu
def show_menu():
    """Show example menu"""

    print("\n" + "=" * 70)
    print("PENTESTING PROFILER - USAGE EXAMPLES")
    print("=" * 70)
    print("\n⚠️  These examples are for AUTHORIZED testing only!\n")
    print("Choose an example:")
    print("  1. Basic scan")
    print("  2. Aggressive scan")
    print("  3. Custom workflow")
    print("  4. Parse results")
    print("  5. Batch scan")
    print("  6. Continuous monitoring")
    print("  7. Export to CSV")
    print("  8. Tool integration")
    print("  0. Exit")
    print()

    choice = input("Enter choice (0-8): ")

    examples = {
        '1': example_basic_scan,
        '2': example_aggressive_scan,
        '3': example_custom_workflow,
        '4': example_parse_results,
        '5': example_batch_scan,
        '6': example_continuous_monitoring,
        '7': example_export_to_csv,
        '8': example_integration_with_tools,
    }

    if choice == '0':
        print("\nExiting...")
        sys.exit(0)

    if choice in examples:
        print()
        examples[choice]()
        input("\nPress Enter to continue...")
        show_menu()
    else:
        print("\nInvalid choice!")
        show_menu()


if __name__ == '__main__':
    # Authorization warning
    print("\n" + "=" * 70)
    print("⚠️  AUTHORIZATION REQUIRED")
    print("=" * 70)
    print("These examples demonstrate authorized penetration testing.")
    print("Only use on systems you own or have explicit permission to test.")
    print("=" * 70)

    confirm = input("\nDo you have authorization? (YES/no): ")

    if confirm.upper() != 'YES':
        print("\nAuthorization not confirmed. Exiting.")
        sys.exit(1)

    show_menu()

#!/usr/bin/env ruby
# frozen_string_literal: true

# 🎯 Proof of Concept Builder
# Purpose: Help structure and document PoCs for bug bounty submissions
# ✅ FOR AUTHORIZED BUG BOUNTY RESEARCH ONLY

require 'fileutils'
require 'date'

class PoCBuilder
  TEMPLATES = {
    'buffer-overflow' => 'Buffer Overflow',
    'use-after-free' => 'Use After Free',
    'integer-overflow' => 'Integer Overflow',
    'type-confusion' => 'Type Confusion',
    'logic-error' => 'Logic Error',
    'race-condition' => 'Race Condition',
    'info-disclosure' => 'Information Disclosure',
    'dos' => 'Denial of Service'
  }.freeze

  def initialize
    @base_dir = File.expand_path('..', __dir__)
    @reports_dir = File.join(@base_dir, 'reports', 'findings')
    @pocs_dir = File.join(@base_dir, 'pocs')

    FileUtils.mkdir_p(@reports_dir)
    FileUtils.mkdir_p(@pocs_dir)
  end

  def create_new_vuln(title, type: 'buffer-overflow')
    puts "🎯 Creating New Vulnerability Report"
    puts "=" * 80
    puts "Title: #{title}"
    puts "Type: #{TEMPLATES[type] || type}"
    puts "=" * 80
    puts

    # Generate unique ID
    vuln_id = "VULN-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"

    # Create directories
    vuln_dir = File.join(@reports_dir, vuln_id)
    FileUtils.mkdir_p(vuln_dir)

    # Create report from template
    report_file = File.join(vuln_dir, 'report.md')
    create_report_file(report_file, title, vuln_id, type)

    # Create PoC template
    poc_file = File.join(vuln_dir, 'poc.py')
    create_poc_file(poc_file, title, vuln_id, type)

    # Create notes file
    notes_file = File.join(vuln_dir, 'notes.md')
    create_notes_file(notes_file, title, vuln_id)

    puts "✅ Vulnerability report structure created!"
    puts
    puts "📁 Report directory: #{vuln_dir}"
    puts "📄 Files created:"
    puts "   - report.md  (Vulnerability report)"
    puts "   - poc.py     (Proof of concept code)"
    puts "   - notes.md   (Research notes)"
    puts
    puts "🎯 Next steps:"
    puts "   1. Fill in the report.md with vulnerability details"
    puts "   2. Develop your PoC in poc.py"
    puts "   3. Document your research in notes.md"
    puts "   4. Run: ./poc_builder.rb --test #{vuln_id}"
    puts
    puts "Vulnerability ID: #{vuln_id}"

    vuln_id
  end

  def list_vulnerabilities
    puts "📋 Your Vulnerability Reports"
    puts "=" * 80
    puts

    vulns = Dir.glob(File.join(@reports_dir, 'VULN-*'))

    if vulns.empty?
      puts "No vulnerabilities documented yet."
      puts "Create one with: ./poc_builder.rb --new 'Vulnerability Title'"
      return
    end

    vulns.sort.reverse.each do |vuln_dir|
      vuln_id = File.basename(vuln_dir)
      report_file = File.join(vuln_dir, 'report.md')

      if File.exist?(report_file)
        # Extract title from report
        content = File.read(report_file)
        title = content[/^# Vulnerability Report: (.+)$/, 1] || 'Untitled'

        puts "🐛 #{vuln_id}"
        puts "   Title: #{title}"
        puts "   Path: #{vuln_dir}"
        puts "   Files: #{Dir.glob(File.join(vuln_dir, '*')).count}"
        puts
      end
    end
  end

  def test_poc(vuln_id)
    vuln_dir = File.join(@reports_dir, vuln_id)

    unless Dir.exist?(vuln_dir)
      puts "❌ Vulnerability not found: #{vuln_id}"
      return
    end

    poc_file = File.join(vuln_dir, 'poc.py')

    unless File.exist?(poc_file)
      puts "❌ PoC file not found: #{poc_file}"
      return
    end

    puts "🧪 Testing Proof of Concept"
    puts "=" * 80
    puts "Vulnerability: #{vuln_id}"
    puts "PoC File: #{poc_file}"
    puts "=" * 80
    puts

    puts "⚠️  SAFETY CHECK:"
    puts "   Are you running this in a safe, isolated environment?"
    print "   Continue? (yes/no): "

    response = gets.chomp.downcase
    unless response == 'yes'
      puts "❌ Test cancelled"
      return
    end

    puts
    puts "▶️  Running PoC..."
    puts "-" * 80

    system("python3", poc_file)

    puts
    puts "-" * 80
    puts "✅ PoC execution complete"
  end

  def generate_submission(vuln_id, program: 'apple')
    vuln_dir = File.join(@reports_dir, vuln_id)

    unless Dir.exist?(vuln_dir)
      puts "❌ Vulnerability not found: #{vuln_id}"
      return
    end

    puts "📤 Generating Bug Bounty Submission"
    puts "=" * 80
    puts "Vulnerability: #{vuln_id}"
    puts "Program: #{program.upcase}"
    puts "=" * 80
    puts

    # Create submission package
    submission_dir = File.join(@base_dir, 'reports', 'submissions', vuln_id)
    FileUtils.mkdir_p(submission_dir)

    # Copy files
    FileUtils.cp_r(Dir.glob(File.join(vuln_dir, '*')), submission_dir)

    # Create submission README
    readme_file = File.join(submission_dir, 'SUBMISSION_README.md')
    create_submission_readme(readme_file, vuln_id, program)

    # Create encrypted archive if possible
    archive_file = File.join(submission_dir, "#{vuln_id}.tar.gz")
    system("tar", "czf", archive_file, "-C", vuln_dir, ".")

    puts "✅ Submission package created!"
    puts
    puts "📁 Submission directory: #{submission_dir}"
    puts "📦 Archive: #{archive_file}"
    puts
    puts "🔐 Encryption (Recommended):"
    puts "   # Encrypt with recipient's PGP key:"
    puts "   gpg --encrypt --recipient security@vendor.com #{archive_file}"
    puts
    puts "📧 Submission Instructions:"

    case program
    when 'apple'
      puts "   Email: product-security@apple.com"
      puts "   URL: https://security.apple.com/bounty/"
      puts "   Subject: Security Vulnerability Report - #{vuln_id}"
    when 'utm'
      puts "   GitHub: https://github.com/utmapp/UTM/issues"
      puts "   Email: Contact maintainer directly"
      puts "   Label: security"
    when 'qemu'
      puts "   Email: secalert@redhat.com"
      puts "   CC: qemu-devel@nongnu.org"
      puts "   Subject: [SECURITY] Vulnerability Report"
    end

    puts
    puts "⏳ Remember:"
    puts "   - Allow 90 days for vendor response"
    puts "   - Don't disclose publicly until patched"
    puts "   - Keep all communication encrypted"
    puts "   - Be patient and professional"
  end

  private

  def create_report_file(path, title, vuln_id, type)
    template_path = File.join(@base_dir, 'disclosure', 'vulnerability_template.md')
    template = File.read(template_path)

    # Customize template
    content = template.dup
    content.gsub!('[Short Title]', title)
    content.gsub!('[YYYYMMDD]-[XXX]', vuln_id.sub('VULN-', ''))
    content.gsub!('[YYYY-MM-DD]', Date.today.to_s)

    File.write(path, content)
  end

  def create_poc_file(path, title, vuln_id, type)
    poc_template = <<~PYTHON
      #!/usr/bin/env python3
      """
      Proof of Concept: #{title}
      Vulnerability ID: #{vuln_id}
      Type: #{TEMPLATES[type] || type}
      Date: #{Date.today}

      DISCLAIMER: For authorized security research only.
      Only run this on systems you own or have explicit permission to test.
      """

      import sys
      import os


      def print_banner():
          """Print PoC banner"""
          print("=" * 80)
          print(f"🎯 PoC: #{title}")
          print(f"📋 Vuln ID: #{vuln_id}")
          print(f"📅 Date: #{Date.today}")
          print("=" * 80)
          print()


      def check_environment():
          """Verify we're in a safe test environment"""
          print("[*] Checking environment...")

          # TODO: Add checks to ensure you're in a safe test environment
          # Example checks:
          # - Verify running in VM
          # - Check for test markers
          # - Confirm isolation

          print("[+] Environment check passed")
          print()


      def setup_exploit():
          """Set up exploit prerequisites"""
          print("[*] Setting up exploit environment...")

          # TODO: Set up any prerequisites for your exploit
          # Example:
          # - Create test files
          # - Configure network
          # - Allocate memory

          print("[+] Setup complete")
          print()


      def trigger_vulnerability():
          """Trigger the vulnerability"""
          print("[*] Triggering vulnerability...")

          # TODO: Implement the actual vulnerability trigger
          # This is where your PoC code goes

          # Example for #{TEMPLATES[type] || type}:
          #{poc_example_code(type)}

          print("[+] Vulnerability triggered")
          print()


      def verify_success():
          """Verify the exploit worked"""
          print("[*] Verifying exploit success...")

          # TODO: Check if the vulnerability was successfully triggered
          # Example:
          # - Check for crash
          # - Verify code execution
          # - Check for data leak

          print("[?] Check system state manually")
          print()


      def cleanup():
          """Clean up after PoC execution"""
          print("[*] Cleaning up...")

          # TODO: Clean up any artifacts
          # Example:
          # - Remove test files
          # - Restore state
          # - Close connections

          print("[+] Cleanup complete")
          print()


      def main():
          """Main PoC execution"""
          print_banner()

          # Safety check
          response = input("⚠️  Run this PoC? (yes/no): ")
          if response.lower() != 'yes':
              print("❌ PoC cancelled")
              sys.exit(0)

          print()

          try:
              check_environment()
              setup_exploit()
              trigger_vulnerability()
              verify_success()
          except Exception as e:
              print(f"❌ Error: {e}")
              import traceback
              traceback.print_exc()
          finally:
              cleanup()

          print("=" * 80)
          print("✅ PoC execution complete")
          print("=" * 80)


      if __name__ == '__main__':
          main()
    PYTHON

    File.write(path, poc_template)
    FileUtils.chmod(0755, path)
  end

  def poc_example_code(type)
    case type
    when 'buffer-overflow'
      <<~CODE.strip.split("\n").map { |l| "# #{l}" }.join("\n")
        # Buffer overflow example:
        # payload = b"A" * 1000  # Overflow buffer
        # send_to_vulnerable_function(payload)
      CODE
    when 'use-after-free'
      <<~CODE.strip.split("\n").map { |l| "# #{l}" }.join("\n")
        # Use-after-free example:
        # obj = allocate_object()
        # free_object(obj)
        # use_object(obj)  # Use after free
      CODE
    when 'integer-overflow'
      <<~CODE.strip.split("\n").map { |l| "# #{l}" }.join("\n")
        # Integer overflow example:
        # size = 0xFFFFFFFF
        # size += 1  # Overflow to 0
        # buffer = allocate(size)  # Allocates 0 bytes
      CODE
    else
      <<~CODE.strip.split("\n").map { |l| "# #{l}" }.join("\n")
        # TODO: Implement your PoC code here
        # Document each step clearly
        # Include comments explaining what happens
      CODE
    end
  end

  def create_notes_file(path, title, vuln_id)
    notes_template = <<~MARKDOWN
      # Research Notes: #{title}

      **Vulnerability ID:** #{vuln_id}
      **Date Started:** #{Date.today}

      ---

      ## Discovery

      ### How I Found It
      [Describe how you discovered this vulnerability]

      ### Initial Observations
      [What made you think this was a vulnerability?]

      ---

      ## Research Timeline

      ### #{Date.today}
      - [Your research activities today]
      - [Observations, tests performed, etc.]

      ---

      ## Technical Details

      ### Affected Code
      ```
      [Paste relevant code snippets]
      ```

      ### Root Cause Analysis
      [Detailed analysis of why this vulnerability exists]

      ### Attack Vector
      [How can this be exploited?]

      ---

      ## Exploitation Notes

      ### Challenges
      [What makes this hard/easy to exploit?]

      ### Requirements
      [What does an attacker need?]

      ### Reliability
      [How reliable is the exploit?]

      ---

      ## Impact Assessment

      ### What Can An Attacker Do?
      - [Impact 1]
      - [Impact 2]

      ### Real-World Scenarios
      [Describe realistic attack scenarios]

      ---

      ## PoC Development

      ### Approach
      [How are you building the PoC?]

      ### Progress
      - [ ] Basic crash
      - [ ] Reliable crash
      - [ ] Control PC/IP
      - [ ] Code execution
      - [ ] Full exploitation

      ### Challenges
      [What's difficult about the PoC?]

      ---

      ## Testing Log

      | Date | Test | Result | Notes |
      |------|------|--------|-------|
      | #{Date.today} | | | |

      ---

      ## Next Steps

      - [ ] Complete PoC
      - [ ] Test on different versions
      - [ ] Document reproduction steps
      - [ ] Prepare disclosure report
      - [ ] Contact vendor

      ---

      ## References

      - [Links to related research]
      - [Documentation]
      - [Similar vulnerabilities]

      ---

      ## Ideas / Random Thoughts

      [Scratch pad for ideas]
    MARKDOWN

    File.write(path, notes_template)
  end

  def create_submission_readme(path, vuln_id, program)
    readme = <<~MARKDOWN
      # Bug Bounty Submission: #{vuln_id}

      **Date:** #{Date.today}
      **Program:** #{program.upcase}

      ---

      ## Package Contents

      This archive contains the complete vulnerability disclosure for #{vuln_id}.

      ### Files Included

      1. **report.md** - Complete vulnerability report
         - Detailed technical description
         - Severity assessment
         - Impact analysis
         - Suggested remediation

      2. **poc.py** - Proof of Concept code
         - Demonstrates the vulnerability
         - Includes usage instructions
         - Safe to run in isolated environment

      3. **notes.md** - Research notes
         - Discovery process
         - Technical analysis
         - Testing logs

      4. **[other files]** - Supporting evidence
         - Crash dumps
         - Screenshots
         - Network captures
         - etc.

      ---

      ## Quick Summary

      [TODO: Add 2-3 sentence summary of the vulnerability]

      **Type:** [VM Escape / Sandbox Escape / etc.]
      **Severity:** [Critical / High / Medium / Low]
      **Impact:** [Brief impact description]

      ---

      ## Reproduction

      See `poc.py` for detailed reproduction steps.

      **Quick test:**
      ```bash
      # In isolated test environment:
      python3 poc.py
      ```

      ---

      ## Contact Information

      **Researcher:** [Your Name]
      **Email:** [your.email@example.com]
      **PGP Key:** [Fingerprint or attached]

      ---

      ## Responsible Disclosure

      This vulnerability is being disclosed responsibly:
      - ✅ Tested only on owned systems
      - ✅ No harm to production systems
      - ✅ Willing to assist with patching
      - ✅ 90-day embargo respected
      - ✅ Coordinated disclosure

      ---

      ## Next Steps

      Please acknowledge receipt of this report and provide:
      1. Timeline for fix development
      2. CVE assignment (if applicable)
      3. Bounty payout information
      4. Public disclosure timeline

      Thank you for your attention to this security issue!
    MARKDOWN

    File.write(path, readme)
  end
end

# Main execution
if __FILE__ == $0
  require 'optparse'
  require 'securerandom'

  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("--new TITLE", "Create new vulnerability report") do |title|
      options[:new] = title
    end

    opts.on("--type TYPE", "Vulnerability type (buffer-overflow, use-after-free, etc.)") do |type|
      options[:type] = type
    end

    opts.on("--list", "List all vulnerabilities") do
      options[:list] = true
    end

    opts.on("--test VULN_ID", "Test PoC for vulnerability") do |id|
      options[:test] = id
    end

    opts.on("--submit VULN_ID", "Generate submission package") do |id|
      options[:submit] = id
    end

    opts.on("--program PROGRAM", "Bug bounty program (apple, utm, qemu)") do |prog|
      options[:program] = prog
    end

    opts.on("-h", "--help", "Show help") do
      puts opts
      puts
      puts "Examples:"
      puts "  # Create new vulnerability report"
      puts "  #{$0} --new 'VM Escape via virtio-net' --type buffer-overflow"
      puts
      puts "  # List all vulnerabilities"
      puts "  #{$0} --list"
      puts
      puts "  # Test a PoC"
      puts "  #{$0} --test VULN-20240103-ABC123"
      puts
      puts "  # Generate submission"
      puts "  #{$0} --submit VULN-20240103-ABC123 --program apple"
      exit
    end
  end.parse!

  builder = PoCBuilder.new

  if options[:new]
    type = options[:type] || 'buffer-overflow'
    vuln_id = builder.create_new_vuln(options[:new], type: type)
  elsif options[:list]
    builder.list_vulnerabilities
  elsif options[:test]
    builder.test_poc(options[:test])
  elsif options[:submit]
    program = options[:program] || 'apple'
    builder.generate_submission(options[:submit], program: program)
  else
    puts "No action specified. Use --help for usage information."
  end
end

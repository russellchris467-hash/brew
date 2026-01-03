#!/usr/bin/env ruby
# frozen_string_literal: true

# 🔴 Red Team Toolkit Master Launcher
# Purpose: Unified interface for all red team tools
# ⚠️ FOR AUTHORIZED SECURITY TESTING ONLY

require 'fileutils'

class RedTeamToolkit
  VERSION = "1.0.0"

  def initialize
    @toolkit_dir = File.dirname(__FILE__)
    @tools = discover_tools
  end

  def run(args)
    if args.empty? || args.include?('--help') || args.include?('-h')
      print_help
      return
    end

    case args[0]
    when 'list'
      list_tools
    when 'info'
      tool_info(args[1])
    when 'recon'
      run_recon(args[1..-1])
    when 'exploit'
      run_exploit(args[1..-1])
    when 'detect'
      run_detect(args[1..-1])
    when 'defend'
      run_defend(args[1..-1])
    when 'full-scan'
      run_full_scan
    when 'demo'
      run_demo
    else
      puts "❌ Unknown command: #{args[0]}"
      puts "Run with --help for usage information"
    end
  end

  private

  def discover_tools
    {
      recon: Dir.glob(File.join(@toolkit_dir, 'recon', '*.rb')),
      exploits: Dir.glob(File.join(@toolkit_dir, 'exploits', '*.rb')),
      detection: Dir.glob(File.join(@toolkit_dir, 'detection', '*.rb')),
      defense: Dir.glob(File.join(@toolkit_dir, 'defense', '*.rb'))
    }
  end

  def print_help
    puts <<~HELP
      🔴 Red Team Toolkit v#{VERSION}
      ═══════════════════════════════════════════════════════════════════════════

      ⚠️  FOR AUTHORIZED SECURITY TESTING AND EDUCATIONAL PURPOSES ONLY

      Usage: #{$0} <command> [options]

      Commands:
        list              📋 List all available tools
        info <tool>       ℹ️  Show information about a specific tool
        recon [tool]      🔍 Run reconnaissance tools
        exploit [tool]    💣 Run exploit demonstrations (REQUIRES AUTHORIZATION)
        detect [tool]     👁️  Run detection utilities
        defend [tool]     🛡️  Run defensive countermeasures
        full-scan         🎯 Run complete security assessment
        demo              🎬 Run safe demonstration mode

      Examples:
        # List all tools
        #{$0} list

        # Run system enumeration
        #{$0} recon system_enum

        # Run data exfiltration POC (safe mode)
        #{$0} exploit data_exfil_poc --dry-run

        # Start process monitoring
        #{$0} detect process_monitor

        # Use sandbox wrapper
        #{$0} defend sandbox_wrapper brew install formula

        # Run full security scan
        #{$0} full-scan

      Tool Categories:

        🔍 Reconnaissance (recon/)
           - system_enum.rb          Complete system profiling
           - homebrew_profile.rb     Homebrew configuration analysis
           - security_audit.rb       Security posture assessment
           - attack_surface.rb       Attack surface mapping

        💣 Exploits (exploits/)
           - data_exfil_poc.rb       Data exfiltration demonstration
           - privilege_persist.rb    Persistence mechanism demo
           - network_beacon.rb       C2 beacon simulation
           - stealth_payload.rb      Evasion techniques

        👁️  Detection (detection/)
           - process_monitor.rb      Process activity tracking
           - network_watch.rb        Network monitoring
           - file_integrity.rb       File system monitoring
           - alert_system.rb         Real-time alerting

        🛡️  Defense (defense/)
           - sandbox_wrapper.rb      Linux sandbox wrapper
           - formula_validator.rb    Formula security scanner
           - network_isolator.sh     Network isolation
           - container_builder.sh    Container deployment

      Documentation:
        README.md                 📖 Complete toolkit documentation
        reports/                  📊 Assessment templates and findings

      ⚠️  LEGAL WARNING:
        This toolkit is for authorized security testing ONLY. Unauthorized use
        may violate computer fraud and abuse laws. Always obtain written
        authorization before testing any system you do not own.

      ═══════════════════════════════════════════════════════════════════════════
    HELP
  end

  def list_tools
    puts "🔴 Red Team Toolkit - Available Tools"
    puts "=" * 80
    puts

    {
      "🔍 Reconnaissance" => @tools[:recon],
      "💣 Exploits" => @tools[:exploits],
      "👁️  Detection" => @tools[:detection],
      "🛡️  Defense" => @tools[:defense]
    }.each do |category, tools|
      puts category
      puts "-" * 80

      if tools.any?
        tools.each do |tool|
          name = File.basename(tool, '.rb')
          puts "  - #{name}"
        end
      else
        puts "  (No tools found)"
      end

      puts
    end
  end

  def tool_info(tool_name)
    return puts "❌ Please specify a tool name" if tool_name.nil?

    # Find tool in all categories
    tool_path = nil
    category = nil

    @tools.each do |cat, tools|
      found = tools.find { |t| File.basename(t, '.rb') == tool_name }
      if found
        tool_path = found
        category = cat
        break
      end
    end

    unless tool_path
      puts "❌ Tool not found: #{tool_name}"
      return
    end

    puts "ℹ️  Tool Information"
    puts "=" * 80
    puts "Name: #{tool_name}"
    puts "Category: #{category}"
    puts "Path: #{tool_path}"
    puts "=" * 80
    puts

    # Read tool header for description
    if File.exist?(tool_path)
      File.open(tool_path) do |f|
        in_header = true
        f.each_line do |line|
          break if line !~ /^#/ && in_header

          if line =~ /^# (.+)/
            puts $1
          end
        end
      end
    end
  end

  def run_recon(args)
    puts "🔍 Running Reconnaissance..."
    puts

    if args.empty?
      # Run all recon tools
      @tools[:recon].each do |tool|
        name = File.basename(tool, '.rb')
        puts "Running: #{name}"
        system("ruby #{tool}")
        puts
      end
    else
      tool_name = args[0]
      tool_path = @tools[:recon].find { |t| File.basename(t, '.rb') == tool_name }

      if tool_path
        exec("ruby", tool_path, *args[1..-1])
      else
        puts "❌ Reconnaissance tool not found: #{tool_name}"
      end
    end
  end

  def run_exploit(args)
    puts "💣 Running Exploit Demonstrations"
    puts "=" * 80
    puts "⚠️  AUTHORIZATION CHECK"
    puts "=" * 80
    puts
    puts "Exploit demonstrations require proper authorization."
    print "Do you have written authorization? (yes/no): "

    response = gets.chomp.downcase
    unless response == 'yes'
      puts "❌ Authorization not confirmed. Exiting."
      return
    end

    puts

    if args.empty?
      puts "Available exploits:"
      @tools[:exploits].each do |tool|
        puts "  - #{File.basename(tool, '.rb')}"
      end
      return
    end

    tool_name = args[0]
    tool_path = @tools[:exploits].find { |t| File.basename(t, '.rb') == tool_name }

    if tool_path
      exec("ruby", tool_path, *args[1..-1])
    else
      puts "❌ Exploit tool not found: #{tool_name}"
    end
  end

  def run_detect(args)
    puts "👁️  Running Detection Utilities..."
    puts

    if args.empty?
      puts "Available detection tools:"
      @tools[:detection].each do |tool|
        puts "  - #{File.basename(tool, '.rb')}"
      end
      return
    end

    tool_name = args[0]
    tool_path = @tools[:detection].find { |t| File.basename(t, '.rb') == tool_name }

    if tool_path
      exec("ruby", tool_path, *args[1..-1])
    else
      puts "❌ Detection tool not found: #{tool_name}"
    end
  end

  def run_defend(args)
    puts "🛡️  Running Defensive Tools..."
    puts

    if args.empty?
      puts "Available defense tools:"
      (@tools[:defense] + Dir.glob(File.join(@toolkit_dir, 'defense', '*.sh'))).each do |tool|
        puts "  - #{File.basename(tool).sub(/\.(rb|sh)$/, '')}"
      end
      return
    end

    tool_name = args[0]
    tool_path = @tools[:defense].find { |t| File.basename(t, '.rb') == tool_name }

    if tool_path
      exec("ruby", tool_path, *args[1..-1])
    else
      # Try shell script
      shell_path = File.join(@toolkit_dir, 'defense', "#{tool_name}.sh")
      if File.exist?(shell_path)
        exec("bash", shell_path, *args[1..-1])
      else
        puts "❌ Defense tool not found: #{tool_name}"
      end
    end
  end

  def run_full_scan
    puts "🎯 Full Security Assessment"
    puts "=" * 80
    puts "This will run a comprehensive security scan including:"
    puts "  1. System enumeration"
    puts "  2. Homebrew profiling"
    puts "  3. Security audit"
    puts "  4. Attack surface mapping"
    puts
    print "Continue? (yes/no): "

    response = gets.chomp.downcase
    return unless response == 'yes'

    puts
    puts "=" * 80
    puts "Starting full security assessment..."
    puts "=" * 80
    puts

    report_dir = File.join(@toolkit_dir, 'reports', "scan_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
    FileUtils.mkdir_p(report_dir)

    # Run system enumeration
    puts "[1/4] Running system enumeration..."
    system("ruby #{File.join(@toolkit_dir, 'recon', 'system_enum.rb')} --save --output=#{report_dir}/system_enum.json")
    puts

    # Additional recon tools would go here
    puts "[2/4] Homebrew profiling..."
    puts "  (Tool would run here if implemented)"
    puts

    puts "[3/4] Security audit..."
    puts "  (Tool would run here if implemented)"
    puts

    puts "[4/4] Attack surface mapping..."
    puts "  (Tool would run here if implemented)"
    puts

    puts "=" * 80
    puts "✅ Full security assessment complete!"
    puts "📊 Reports saved to: #{report_dir}"
    puts "=" * 80
  end

  def run_demo
    puts "🎬 Red Team Toolkit Demonstration"
    puts "=" * 80
    puts "Running safe demonstrations of toolkit capabilities..."
    puts "=" * 80
    puts

    # 1. System enumeration
    puts "[1] 🔍 System Enumeration Demo"
    puts "-" * 80
    system("ruby #{File.join(@toolkit_dir, 'recon', 'system_enum.rb')}")
    puts
    puts "Press Enter to continue..."
    gets

    # 2. Data exfiltration POC (dry run)
    puts "[2] 💣 Data Exfiltration POC (Safe Mode)"
    puts "-" * 80
    system("ruby #{File.join(@toolkit_dir, 'exploits', 'data_exfil_poc.rb')} --dry-run")
    puts
    puts "Press Enter to continue..."
    gets

    # 3. Sandbox wrapper
    puts "[3] 🛡️  Sandbox Wrapper Demo"
    puts "-" * 80
    system("ruby #{File.join(@toolkit_dir, 'defense', 'sandbox_wrapper.rb')} --dry-run echo 'Hello from sandbox'")
    puts

    puts "=" * 80
    puts "✅ Demonstration complete!"
    puts "=" * 80
  end
end

# Main execution
if __FILE__ == $0
  toolkit = RedTeamToolkit.new
  toolkit.run(ARGV)
end

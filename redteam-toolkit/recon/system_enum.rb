#!/usr/bin/env ruby
# frozen_string_literal: true

# 🔍 System Enumeration Tool
# Purpose: Complete system profiling for red team reconnaissance
# ⚠️ FOR AUTHORIZED SECURITY TESTING ONLY

require 'json'
require 'etc'
require 'socket'

class SystemEnumerator
  def initialize
    @results = {}
    @timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  end

  def run_full_enumeration
    puts "🔍 System Enumeration Starting..."
    puts "⏰ Timestamp: #{@timestamp}"
    puts "=" * 80
    puts

    enumerate_os_info
    enumerate_hardware
    enumerate_user_context
    enumerate_homebrew
    enumerate_network
    enumerate_security_controls
    enumerate_privileges
    enumerate_environment

    puts
    puts "=" * 80
    puts "✅ Enumeration Complete!"
    puts

    @results
  end

  private

  def enumerate_os_info
    puts "[1] 🐧 Operating System Information"
    puts "-" * 80

    @results[:os] = {}

    # Platform detection
    @results[:os][:platform] = RUBY_PLATFORM
    puts "Platform: #{RUBY_PLATFORM}"

    # OS release info
    if File.exist?("/etc/os-release")
      os_release = File.read("/etc/os-release")
      os_release.each_line do |line|
        if line =~ /^NAME="(.+)"/
          @results[:os][:name] = $1
          puts "OS Name: #{$1}"
        elsif line =~ /^VERSION="(.+)"/
          @results[:os][:version] = $1
          puts "OS Version: #{$1}"
        elsif line =~ /^ID=(.+)/
          @results[:os][:id] = $1.gsub('"', '')
          puts "OS ID: #{$1}"
        end
      end
    end

    # Kernel version
    kernel = `uname -r 2>/dev/null`.strip
    @results[:os][:kernel] = kernel
    puts "Kernel: #{kernel}" unless kernel.empty?

    # Architecture
    arch = `uname -m 2>/dev/null`.strip
    @results[:os][:architecture] = arch
    puts "Architecture: #{arch}" unless arch.empty?

    puts
  end

  def enumerate_hardware
    puts "[2] 💻 Hardware Information"
    puts "-" * 80

    @results[:hardware] = {}

    # CPU info
    if File.exist?("/proc/cpuinfo")
      cpuinfo = File.read("/proc/cpuinfo")

      # CPU model
      if cpuinfo =~ /model name\s*:\s*(.+)/
        @results[:hardware][:cpu_model] = $1
        puts "CPU Model: #{$1}"
      end

      # CPU cores
      cores = cpuinfo.scan(/^processor/).count
      @results[:hardware][:cpu_cores] = cores
      puts "CPU Cores: #{cores}"

      # ARM detection
      is_arm = cpuinfo =~ /ARM|aarch64/i
      @results[:hardware][:is_arm] = !is_arm.nil?
      puts "ARM Architecture: #{is_arm ? '✅ YES' : '❌ NO'}"
    end

    # Memory info
    if File.exist?("/proc/meminfo")
      meminfo = File.read("/proc/meminfo")
      if meminfo =~ /MemTotal:\s+(\d+)/
        mem_kb = $1.to_i
        mem_gb = (mem_kb / 1024.0 / 1024.0).round(2)
        @results[:hardware][:memory_gb] = mem_gb
        puts "Total Memory: #{mem_gb} GB"
      end
    end

    puts
  end

  def enumerate_user_context
    puts "[3] 👤 User Context"
    puts "-" * 80

    @results[:user] = {}

    # Current user
    user = Etc.getlogin || ENV['USER']
    @results[:user][:username] = user
    puts "Username: #{user}"

    # User ID
    uid = Process.uid
    @results[:user][:uid] = uid
    puts "UID: #{uid}"

    # Effective UID
    euid = Process.euid
    @results[:user][:euid] = euid
    puts "Effective UID: #{euid}"

    # Groups
    groups = `groups 2>/dev/null`.strip
    @results[:user][:groups] = groups
    puts "Groups: #{groups}" unless groups.empty?

    # Home directory
    home = ENV['HOME']
    @results[:user][:home] = home
    puts "Home Directory: #{home}"

    # Shell
    shell = ENV['SHELL']
    @results[:user][:shell] = shell
    puts "Shell: #{shell}"

    # Sudo access
    has_sudo = system('sudo -n true 2>/dev/null')
    @results[:user][:has_sudo] = has_sudo
    puts "Sudo Access: #{has_sudo ? '✅ YES (CRITICAL!)' : '❌ NO'}"

    puts
  end

  def enumerate_homebrew
    puts "[4] 🍺 Homebrew Configuration"
    puts "-" * 80

    @results[:homebrew] = {}

    # Homebrew installation
    brew_path = `which brew 2>/dev/null`.strip
    if brew_path.empty?
      puts "Homebrew: ❌ NOT INSTALLED"
      @results[:homebrew][:installed] = false
    else
      @results[:homebrew][:installed] = true
      @results[:homebrew][:path] = brew_path
      puts "Homebrew Path: #{brew_path}"

      # Homebrew prefix
      prefix = `brew --prefix 2>/dev/null`.strip
      @results[:homebrew][:prefix] = prefix
      puts "Homebrew Prefix: #{prefix}" unless prefix.empty?

      # Homebrew version
      version = `brew --version 2>/dev/null`.split("\n").first
      @results[:homebrew][:version] = version
      puts "Homebrew Version: #{version}" unless version.nil?

      # Check for sandbox-exec (macOS only)
      sandbox_exec = File.executable?("/usr/bin/sandbox-exec")
      @results[:homebrew][:sandbox_available] = sandbox_exec
      puts "Sandbox Available: #{sandbox_exec ? '✅ YES' : '❌ NO (ESCAPE CONDITION!)'}"

      # Installed formulae count
      formulae = `brew list --formula 2>/dev/null`.split("\n")
      @results[:homebrew][:formula_count] = formulae.count
      puts "Installed Formulae: #{formulae.count}"

      # Installed taps
      taps = `brew tap 2>/dev/null`.split("\n")
      @results[:homebrew][:taps] = taps
      puts "Taps: #{taps.join(', ')}" unless taps.empty?
    end

    puts
  end

  def enumerate_network
    puts "[5] 🌐 Network Configuration"
    puts "-" * 80

    @results[:network] = {}

    # Hostname
    hostname = Socket.gethostname
    @results[:network][:hostname] = hostname
    puts "Hostname: #{hostname}"

    # IP addresses
    ips = Socket.ip_address_list.select(&:ipv4?).map(&:ip_address)
    @results[:network][:ip_addresses] = ips
    puts "IP Addresses: #{ips.join(', ')}"

    # Check internet connectivity
    has_internet = system('ping -c 1 8.8.8.8 > /dev/null 2>&1')
    @results[:network][:internet_access] = has_internet
    puts "Internet Access: #{has_internet ? '✅ YES' : '❌ NO'}"

    # Active connections
    connections = `netstat -tuln 2>/dev/null | grep LISTEN`.split("\n").count
    @results[:network][:listening_ports] = connections
    puts "Listening Ports: #{connections}"

    # DNS servers
    if File.exist?("/etc/resolv.conf")
      dns_servers = File.read("/etc/resolv.conf").scan(/nameserver\s+(.+)/).flatten
      @results[:network][:dns_servers] = dns_servers
      puts "DNS Servers: #{dns_servers.join(', ')}" unless dns_servers.empty?
    end

    puts
  end

  def enumerate_security_controls
    puts "[6] 🔒 Security Controls"
    puts "-" * 80

    @results[:security] = {}

    # SELinux
    selinux_status = `getenforce 2>/dev/null`.strip
    unless selinux_status.empty?
      @results[:security][:selinux] = selinux_status
      puts "SELinux: #{selinux_status}"
    end

    # AppArmor
    apparmor_status = `aa-status 2>/dev/null | grep 'apparmor module'`.strip
    unless apparmor_status.empty?
      @results[:security][:apparmor] = "enabled"
      puts "AppArmor: Enabled"
    end

    # Firewall
    ufw_status = `ufw status 2>/dev/null | grep Status`.strip
    unless ufw_status.empty?
      @results[:security][:firewall_ufw] = ufw_status
      puts "UFW Firewall: #{ufw_status}"
    end

    iptables_rules = `iptables -L 2>/dev/null | wc -l`.strip.to_i
    if iptables_rules > 0
      @results[:security][:firewall_iptables] = "#{iptables_rules} rules"
      puts "IPTables: #{iptables_rules} rules"
    end

    # Audit daemon
    auditd_running = system('systemctl is-active --quiet auditd 2>/dev/null')
    @results[:security][:auditd] = auditd_running
    puts "Auditd: #{auditd_running ? '✅ Running' : '❌ Not running'}"

    puts
  end

  def enumerate_privileges
    puts "[7] 🔑 Privilege Escalation Vectors"
    puts "-" * 80

    @results[:privesc] = {}

    # SUID binaries (common locations)
    suid_paths = ['/usr/bin', '/usr/sbin', '/bin', '/sbin']
    suid_binaries = []

    suid_paths.each do |path|
      next unless Dir.exist?(path)

      Dir.glob("#{path}/*").each do |file|
        next unless File.file?(file)

        stat = File.stat(file)
        if (stat.mode & 04000) != 0  # SUID bit
          suid_binaries << file
        end
      end
    end

    @results[:privesc][:suid_binaries] = suid_binaries
    puts "SUID Binaries Found: #{suid_binaries.count}"
    if suid_binaries.count > 0 && suid_binaries.count < 20
      suid_binaries.each { |bin| puts "  - #{bin}" }
    end

    # Writable paths in PATH
    writable_paths = ENV['PATH'].split(':').select do |path|
      File.directory?(path) && File.writable?(path)
    end
    @results[:privesc][:writable_path_dirs] = writable_paths
    puts "Writable PATH directories: #{writable_paths.count}"
    writable_paths.each { |path| puts "  ⚠️  #{path}" } if writable_paths.any?

    # World-writable files (quick sample)
    world_writable = `find /tmp /var/tmp -type f -perm -002 2>/dev/null | head -10`.split("\n")
    @results[:privesc][:world_writable_sample] = world_writable
    puts "World-writable files (sample): #{world_writable.count}"

    puts
  end

  def enumerate_environment
    puts "[8] 🌍 Environment Variables"
    puts "-" * 80

    @results[:environment] = {}

    # Sensitive environment variables
    sensitive_vars = %w[
      PATH HOME USER SHELL SUDO_USER
      SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION
      AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
      GITHUB_TOKEN HOMEBREW_GITHUB_API_TOKEN
      API_KEY SECRET_KEY
    ]

    found_vars = {}
    sensitive_vars.each do |var|
      value = ENV[var]
      next if value.nil? || value.empty?

      # Redact sensitive values
      if var =~ /KEY|TOKEN|SECRET|PASSWORD/
        display_value = value[0..4] + "..." + value[-4..-1] rescue "***"
      else
        display_value = value
      end

      found_vars[var] = value
      puts "#{var}: #{display_value}"
    end

    @results[:environment][:sensitive_vars] = found_vars.keys
    @results[:environment][:total_vars] = ENV.keys.count
    puts
    puts "Total Environment Variables: #{ENV.keys.count}"
    puts "Sensitive Variables Found: #{found_vars.count}"

    puts
  end

  def save_report(filename = "system_enum_report.json")
    File.write(filename, JSON.pretty_generate(@results))
    puts "📄 Report saved to: #{filename}"
  end
end

# Main execution
if __FILE__ == $0
  puts "🔴 Red Team Toolkit - System Enumerator"
  puts "⚠️  FOR AUTHORIZED SECURITY TESTING ONLY"
  puts

  if ARGV.include?('--check')
    puts "✅ Tool is operational"
    exit 0
  end

  enumerator = SystemEnumerator.new
  results = enumerator.run_full_enumeration

  # Save report if requested
  if ARGV.include?('--full') || ARGV.include?('--save')
    report_path = ARGV.find { |arg| arg.start_with?('--output=') }&.split('=')&.last
    report_path ||= "/home/user/brew/redteam-toolkit/reports/system_enum_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"

    File.write(report_path, JSON.pretty_generate(results))
    puts "📊 Full report saved to: #{report_path}"
  end

  # Risk summary
  puts
  puts "🚨 RISK SUMMARY"
  puts "=" * 80

  risks = []

  if !results.dig(:homebrew, :sandbox_available)
    risks << "🔴 CRITICAL: Homebrew sandbox NOT available (escape condition exists)"
  end

  if results.dig(:user, :has_sudo)
    risks << "🟡 HIGH: User has sudo access"
  end

  if results.dig(:privesc, :writable_path_dirs)&.any?
    risks << "🟡 MEDIUM: Writable directories in PATH"
  end

  if !results.dig(:security, :auditd)
    risks << "🟡 MEDIUM: Audit logging not enabled"
  end

  if results.dig(:network, :internet_access)
    risks << "🟢 INFO: Internet access available (exfiltration possible)"
  end

  if risks.any?
    risks.each { |risk| puts risk }
  else
    puts "✅ No major risks identified"
  end

  puts "=" * 80
end

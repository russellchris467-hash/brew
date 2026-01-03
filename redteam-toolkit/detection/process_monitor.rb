#!/usr/bin/env ruby
# frozen_string_literal: true

# 👁️ Process Monitor
# Purpose: Monitor Homebrew processes for suspicious activity
# ⚠️ FOR AUTHORIZED SECURITY MONITORING ONLY

require 'json'
require 'time'

class ProcessMonitor
  SUSPICIOUS_PATTERNS = [
    /curl.*-X POST/i,           # HTTP POST requests
    /wget.*--post/i,            # Wget POST requests
    /nc.*-e/i,                  # Netcat with command execution
    /bash -c/i,                 # Bash command execution
    /sh -c/i,                   # Shell command execution
    /eval/i,                    # Eval execution
    /python.*-c/i,              # Python one-liners
    /perl.*-e/i,                # Perl one-liners
    /ruby.*-e/i,                # Ruby one-liners
    /base64.*-d/i,              # Base64 decoding
    /ssh.*@/i,                  # SSH connections
    /scp.*@/i,                  # SCP file transfers
    /rsync.*@/i,                # Rsync transfers
    /\.ssh/,                    # SSH directory access
    /\.aws\/credentials/,       # AWS credentials
    /\.docker\/config/,         # Docker config
    /\.npmrc/,                  # NPM config
    /env.*grep.*-i.*key/i,      # Environment variable grepping
    /chmod.*\+[sx]/i,           # SUID/SGID bit setting
    /crontab/i,                 # Cron manipulation
    /systemctl/i,               # Systemd manipulation
    /\.bashrc|\.zshrc|\.profile/, # Shell profile modification
  ].freeze

  def initialize(log_file: nil, daemon: false)
    @log_file = log_file || "/tmp/brew_process_monitor.log"
    @daemon = daemon
    @alerts = []
    @start_time = Time.now
  end

  def start
    puts "👁️  Process Monitor Starting"
    puts "=" * 80
    puts "Log file: #{@log_file}"
    puts "Mode: #{@daemon ? 'Daemon' : 'Interactive'}"
    puts "Started: #{@start_time}"
    puts "=" * 80
    puts

    if @daemon
      daemonize
    else
      monitor_loop
    end
  end

  private

  def monitor_loop
    puts "Monitoring Homebrew processes (Ctrl+C to stop)..."
    puts

    loop do
      check_processes
      sleep 2
    end
  rescue Interrupt
    puts
    puts
    print_summary
  end

  def check_processes
    # Find all brew-related processes
    brew_processes = `ps aux | grep -E 'brew|ruby.*formula' | grep -v grep`.split("\n")

    return if brew_processes.empty?

    brew_processes.each do |process_line|
      analyze_process(process_line)
    end

    # Check for suspicious child processes
    check_child_processes
  end

  def analyze_process(process_line)
    # Parse process info
    parts = process_line.split(/\s+/, 11)
    return if parts.length < 11

    user = parts[0]
    pid = parts[1]
    cpu = parts[2]
    mem = parts[3]
    command = parts[10]

    # Check against suspicious patterns
    SUSPICIOUS_PATTERNS.each do |pattern|
      next unless command =~ pattern

      alert = create_alert(
        type: :suspicious_command,
        severity: :high,
        pid: pid,
        user: user,
        command: command,
        pattern: pattern.source,
        timestamp: Time.now
      )

      log_alert(alert)
      display_alert(alert)
    end

    # Check for long-running processes (potential persistence)
    check_process_duration(pid, command)

    # Check for high resource usage (potential mining/DoS)
    check_resource_usage(pid, cpu, mem, command)
  end

  def check_child_processes
    # Get process tree for brew processes
    brew_pids = `pgrep -f brew`.split("\n")

    brew_pids.each do |pid|
      children = `pgrep -P #{pid}`.split("\n")

      children.each do |child_pid|
        child_cmd = `ps -p #{child_pid} -o command=`.strip

        # Check if child is suspicious
        if child_cmd =~ /nc|netcat|socat|telnet|ftp|curl|wget/
          alert = create_alert(
            type: :suspicious_child,
            severity: :critical,
            pid: child_pid,
            parent_pid: pid,
            command: child_cmd,
            timestamp: Time.now
          )

          log_alert(alert)
          display_alert(alert)
        end
      end
    end
  end

  def check_process_duration(pid, command)
    # Get process start time
    start_time_str = `ps -p #{pid} -o lstart=`.strip
    return if start_time_str.empty?

    begin
      process_start = Time.parse(start_time_str)
      duration = Time.now - process_start

      # Alert if process has been running > 10 minutes
      if duration > 600 && command =~ /brew install|brew upgrade/
        alert = create_alert(
          type: :long_running,
          severity: :medium,
          pid: pid,
          command: command,
          duration: duration.to_i,
          timestamp: Time.now
        )

        log_alert(alert)
        display_alert(alert)
      end
    rescue ArgumentError
      # Failed to parse time
    end
  end

  def check_resource_usage(pid, cpu, mem, command)
    cpu_val = cpu.to_f
    mem_val = mem.to_f

    # Alert on high CPU usage (> 80%)
    if cpu_val > 80.0
      alert = create_alert(
        type: :high_cpu,
        severity: :medium,
        pid: pid,
        command: command,
        cpu: cpu_val,
        timestamp: Time.now
      )

      log_alert(alert)
      display_alert(alert)
    end

    # Alert on high memory usage (> 50%)
    if mem_val > 50.0
      alert = create_alert(
        type: :high_memory,
        severity: :medium,
        pid: pid,
        command: command,
        memory: mem_val,
        timestamp: Time.now
      )

      log_alert(alert)
      display_alert(alert)
    end
  end

  def create_alert(params)
    alert = params.merge(
      id: @alerts.count + 1,
      hostname: `hostname`.strip,
      monitor_uptime: Time.now - @start_time
    )

    @alerts << alert
    alert
  end

  def log_alert(alert)
    File.open(@log_file, 'a') do |f|
      f.puts JSON.generate(alert)
    end
  end

  def display_alert(alert)
    severity_emoji = case alert[:severity]
    when :critical then "🔴"
    when :high then "🟠"
    when :medium then "🟡"
    when :low then "🔵"
    else "⚪"
    end

    puts "#{severity_emoji} [#{alert[:timestamp].strftime('%H:%M:%S')}] #{alert[:type].to_s.upcase}"
    puts "   PID: #{alert[:pid]}"
    puts "   Command: #{alert[:command]}"

    case alert[:type]
    when :suspicious_command
      puts "   Pattern: #{alert[:pattern]}"
    when :suspicious_child
      puts "   Parent PID: #{alert[:parent_pid]}"
    when :long_running
      puts "   Duration: #{alert[:duration]}s (#{(alert[:duration] / 60).to_i}m)"
    when :high_cpu
      puts "   CPU Usage: #{alert[:cpu]}%"
    when :high_memory
      puts "   Memory Usage: #{alert[:memory]}%"
    end

    puts
  end

  def print_summary
    puts "=" * 80
    puts "👁️  MONITORING SUMMARY"
    puts "=" * 80
    puts "Duration: #{((Time.now - @start_time) / 60).round(1)} minutes"
    puts "Total alerts: #{@alerts.count}"
    puts

    if @alerts.any?
      puts "Alerts by severity:"
      %i[critical high medium low].each do |severity|
        count = @alerts.select { |a| a[:severity] == severity }.count
        puts "  #{severity.to_s.upcase}: #{count}" if count > 0
      end
      puts

      puts "Alerts by type:"
      alert_types = @alerts.group_by { |a| a[:type] }
      alert_types.each do |type, alerts|
        puts "  #{type}: #{alerts.count}"
      end
    else
      puts "✅ No alerts detected"
    end

    puts
    puts "Full log: #{@log_file}"
    puts "=" * 80
  end

  def daemonize
    puts "Running in daemon mode..."
    puts "Logs: #{@log_file}"
    puts "PID will be written to /tmp/brew_monitor.pid"
    puts

    # Fork to background
    pid = fork do
      Process.daemon(true)

      # Write PID file
      File.write('/tmp/brew_monitor.pid', Process.pid)

      # Reopen log file
      $stdout.reopen(@log_file, 'a')
      $stderr.reopen(@log_file, 'a')
      $stdout.sync = true
      $stderr.sync = true

      puts "Daemon started at #{Time.now}"
      puts "PID: #{Process.pid}"

      # Monitor loop
      loop do
        check_processes
        sleep 2
      end
    end

    puts "✅ Daemon started with PID: #{pid}"
    puts "To stop: kill #{pid}"
  end
end

# Main execution
if __FILE__ == $0
  require 'optparse'

  options = {
    log_file: nil,
    daemon: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("--log FILE", "Log file path") do |file|
      options[:log_file] = file
    end

    opts.on("--daemon", "Run as daemon") do
      options[:daemon] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  monitor = ProcessMonitor.new(
    log_file: options[:log_file],
    daemon: options[:daemon]
  )

  monitor.start
end

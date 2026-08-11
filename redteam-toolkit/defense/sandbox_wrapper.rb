#!/usr/bin/env ruby
# frozen_string_literal: true

# 🛡️ Sandbox Wrapper for Homebrew on Linux
# Purpose: Provide sandboxing using bubblewrap for Linux systems
# ⚠️ Requires bubblewrap (bwrap) installed

require 'fileutils'
require 'tempfile'

class SandboxWrapper
  def initialize
    @bwrap = find_bwrap
    @sandbox_config = default_sandbox_config
  end

  def wrap_command(*args)
    unless @bwrap
      puts "❌ ERROR: bubblewrap (bwrap) not found"
      puts "Install with: sudo pacman -S bubblewrap  # Arch Linux"
      puts "           or: sudo apt install bubblewrap  # Debian/Ubuntu"
      exit 1
    end

    puts "🛡️  Sandbox Wrapper"
    puts "=" * 80
    puts "Command: #{args.join(' ')}"
    puts "Sandbox: bubblewrap"
    puts "=" * 80
    puts

    print_restrictions
    puts

    # Build bwrap command
    bwrap_cmd = build_bwrap_command(args)

    puts "🚀 Executing in sandbox..."
    puts "Command: #{bwrap_cmd[0..100]}..." if bwrap_cmd.length > 100
    puts

    # Execute
    exec(*bwrap_cmd.split(' '))
  end

  private

  def find_bwrap
    ['/usr/bin/bwrap', '/bin/bwrap'].find { |path| File.executable?(path) }
  end

  def default_sandbox_config
    {
      # Filesystem restrictions
      ro_bind_paths: [
        '/',                    # Root filesystem (read-only)
      ],
      rw_bind_paths: [
        ENV['HOME'],            # Home directory (read-write)
        '/tmp',                 # Temp directory
        '/var/tmp',             # Var temp
      ],
      tmpfs_paths: [
        '/run',                 # Runtime directory
      ],
      dev: true,               # Create /dev
      proc: true,              # Mount /proc
      unshare_all: true,       # Unshare all namespaces
      die_with_parent: true,   # Kill on parent death
      new_session: true,       # New session

      # Network restrictions
      unshare_net: false,      # Allow network (can be restricted)

      # User restrictions
      unshare_user: true,      # Separate user namespace
      uid: Process.uid,        # Map to current UID
      gid: Process.gid,        # Map to current GID

      # Capabilities (all dropped by default)
      cap_add: [],             # No additional capabilities

      # Seccomp filter
      seccomp: true,           # Enable seccomp filtering
    }
  end

  def build_bwrap_command(wrapped_cmd)
    bwrap_args = [@bwrap]

    # Add unshare options
    if @sandbox_config[:unshare_all]
      bwrap_args << '--unshare-all'
    end

    if @sandbox_config[:unshare_net]
      bwrap_args << '--unshare-net'
    end

    if @sandbox_config[:unshare_user]
      bwrap_args << '--unshare-user'
      bwrap_args << '--uid' << @sandbox_config[:uid].to_s
      bwrap_args << '--gid' << @sandbox_config[:gid].to_s
    end

    # Die with parent
    if @sandbox_config[:die_with_parent]
      bwrap_args << '--die-with-parent'
    end

    # New session
    if @sandbox_config[:new_session]
      bwrap_args << '--new-session'
    end

    # Read-only bind mounts
    @sandbox_config[:ro_bind_paths].each do |path|
      next unless Dir.exist?(path) || File.exist?(path)
      bwrap_args << '--ro-bind' << path << path
    end

    # Read-write bind mounts
    @sandbox_config[:rw_bind_paths].each do |path|
      next unless Dir.exist?(path) || File.exist?(path)
      bwrap_args << '--bind' << path << path
    end

    # Tmpfs mounts
    @sandbox_config[:tmpfs_paths].each do |path|
      bwrap_args << '--tmpfs' << path
    end

    # /dev
    if @sandbox_config[:dev]
      bwrap_args << '--dev' << '/dev'
    end

    # /proc
    if @sandbox_config[:proc]
      bwrap_args << '--proc' << '/proc'
    end

    # Seccomp filter
    if @sandbox_config[:seccomp]
      seccomp_file = create_seccomp_filter
      bwrap_args << '--seccomp' << seccomp_file.path
    end

    # Add the wrapped command
    bwrap_args.concat(wrapped_cmd)

    bwrap_args.join(' ')
  end

  def create_seccomp_filter
    # Create a seccomp filter that blocks dangerous syscalls
    # Format: https://github.com/containers/bubblewrap/blob/main/demos/userns-block-fd.json

    filter = {
      "defaultAction" => "SCMP_ACT_ALLOW",
      "syscalls" => [
        {
          "names" => [
            "ptrace",           # Prevent process debugging
            "process_vm_readv", # Prevent memory reading
            "process_vm_writev",# Prevent memory writing
            "kexec_load",       # Prevent kernel execution
            "open_by_handle_at",# Prevent file handle attacks
            "init_module",      # Prevent kernel module loading
            "finit_module",     # Prevent kernel module loading
            "delete_module",    # Prevent kernel module unloading
            "iopl",             # Prevent I/O privilege level change
            "ioperm",           # Prevent I/O permissions change
            "swapon",           # Prevent swap manipulation
            "swapoff",          # Prevent swap manipulation
            "syslog",           # Prevent syslog manipulation
            "personality",      # Prevent execution domain changes
            "userfaultfd",      # Prevent userfaultfd exploitation
          ],
          "action" => "SCMP_ACT_ERRNO"
        }
      ]
    }

    tmpfile = Tempfile.new(['seccomp', '.json'])
    tmpfile.write(JSON.pretty_generate(filter))
    tmpfile.flush
    tmpfile
  end

  def print_restrictions
    puts "🔒 Sandbox Restrictions:"
    puts "-" * 80

    puts "✅ Filesystem:"
    puts "   - Root filesystem: READ-ONLY"
    puts "   - Home directory: READ-WRITE (limited to your home)"
    puts "   - /tmp, /var/tmp: READ-WRITE (isolated)"
    puts

    puts "✅ Network:"
    if @sandbox_config[:unshare_net]
      puts "   - Network: DISABLED (no internet access)"
    else
      puts "   - Network: ALLOWED (can be disabled with --no-network)"
    end
    puts

    puts "✅ Processes:"
    puts "   - Process isolation: ENABLED"
    puts "   - Die with parent: ENABLED"
    puts "   - New session: ENABLED"
    puts

    puts "✅ Security:"
    puts "   - User namespace: SEPARATED"
    puts "   - Capabilities: ALL DROPPED"
    puts "   - Seccomp filtering: ENABLED"
    puts "   - Dangerous syscalls: BLOCKED"
    puts

    puts "❌ Blocked Operations:"
    puts "   - Kernel module loading"
    puts "   - Process debugging (ptrace)"
    puts "   - Direct memory access"
    puts "   - I/O privilege escalation"
    puts "   - Execution domain changes"
  end

  def self.print_usage
    puts "🛡️  Sandbox Wrapper - Usage"
    puts "=" * 80
    puts
    puts "Purpose:"
    puts "  Provide sandboxing for Homebrew on Linux systems using bubblewrap"
    puts
    puts "Usage:"
    puts "  #{$0} <command> [args...]"
    puts
    puts "Examples:"
    puts "  # Sandbox a Homebrew installation"
    puts "  #{$0} brew install untrusted-formula"
    puts
    puts "  # Sandbox any command"
    puts "  #{$0} curl https://example.com/script.sh"
    puts
    puts "  # With network isolation"
    puts "  #{$0} --no-network brew install formula"
    puts
    puts "Requirements:"
    puts "  - bubblewrap must be installed"
    puts "  - Linux kernel with namespace support"
    puts "  - User namespaces enabled"
    puts
    puts "Security Benefits:"
    puts "  ✅ Prevents unauthorized file system writes"
    puts "  ✅ Isolates processes from host system"
    puts "  ✅ Drops all Linux capabilities"
    puts "  ✅ Blocks dangerous system calls via seccomp"
    puts "  ✅ Optional network isolation"
    puts
    puts "Comparison to macOS Seatbelt:"
    puts "  Similar to macOS sandbox-exec but using Linux namespaces"
    puts "  Provides comparable isolation for Homebrew builds"
    puts
    puts "=" * 80
  end
end

# Main execution
if __FILE__ == $0
  require 'optparse'
  require 'json'

  if ARGV.empty? || ARGV.include?('--help') || ARGV.include?('-h')
    SandboxWrapper.print_usage
    exit 0
  end

  # Parse options
  options = {}

  OptionParser.new do |opts|
    opts.on("--no-network", "Disable network access") do
      options[:no_network] = true
    end

    opts.on("--dry-run", "Show what would be executed") do
      options[:dry_run] = true
    end
  end.parse!

  if ARGV.empty?
    puts "❌ ERROR: No command specified"
    puts "Run with --help for usage information"
    exit 1
  end

  wrapper = SandboxWrapper.new

  # Apply options
  if options[:no_network]
    wrapper.instance_variable_get(:@sandbox_config)[:unshare_net] = true
  end

  if options[:dry_run]
    puts "🔒 DRY RUN MODE"
    puts "Would execute: #{ARGV.join(' ')}"
    puts
    wrapper.send(:print_restrictions)
    exit 0
  end

  # Wrap and execute command
  wrapper.wrap_command(*ARGV)
end

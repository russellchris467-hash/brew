#!/usr/bin/env ruby
# frozen_string_literal: true

# 🔬 Hypervisor Enumeration Tool
# Purpose: Enumerate hypervisor information for bug bounty research
# ✅ FOR AUTHORIZED BUG BOUNTY RESEARCH ONLY

require 'json'

class HypervisorEnumerator
  def initialize
    @findings = {}
    @platform = detect_platform
  end

  def enumerate(deep: false)
    puts "🔬 Hypervisor Enumeration Tool"
    puts "=" * 80
    puts "Platform: #{@platform}"
    puts "Mode: #{deep ? 'Deep Analysis' : 'Quick Scan'}"
    puts "=" * 80
    puts

    detect_virtualization
    enumerate_cpu_features
    detect_hypervisor_type
    enumerate_virtual_devices
    check_shared_memory
    detect_paravirt_features
    enumerate_security_features

    if deep
      deep_analysis
    end

    print_summary
    generate_report
  end

  private

  def detect_platform
    case RUBY_PLATFORM
    when /darwin/
      "macOS"
    when /linux/
      "Linux"
    else
      "Unknown"
    end
  end

  def detect_virtualization
    puts "[1] 🖥️  Virtualization Detection"
    puts "-" * 80

    @findings[:virtualized] = false

    # Check /proc/cpuinfo for hypervisor flag (Linux)
    if File.exist?("/proc/cpuinfo")
      cpuinfo = File.read("/proc/cpuinfo")

      if cpuinfo =~ /hypervisor/
        puts "✅ Running in virtual machine (hypervisor flag present)"
        @findings[:virtualized] = true
      else
        puts "❌ Not running in virtual machine (no hypervisor flag)"
      end

      # Check for specific hypervisor signatures
      if cpuinfo =~ /QEMU/i
        puts "🎯 Hypervisor: QEMU detected"
        @findings[:hypervisor] = "QEMU"
      elsif cpuinfo =~ /VMware/i
        puts "🎯 Hypervisor: VMware detected"
        @findings[:hypervisor] = "VMware"
      elsif cpuinfo =~ /KVM/i
        puts "🎯 Hypervisor: KVM detected"
        @findings[:hypervisor] = "KVM"
      end
    end

    # macOS detection
    if @platform == "macOS"
      # Check for Apple Hypervisor Framework
      sysctl_output = `sysctl -a 2>/dev/null | grep -i hypervisor`
      unless sysctl_output.empty?
        puts "✅ Apple Hypervisor Framework present"
        @findings[:hypervisor] = "Apple Hypervisor Framework"
      end

      # Check for UTM-specific indicators
      if `ps aux | grep -i utm | grep -v grep`.strip.length > 0
        puts "🎯 UTM virtualization detected!"
        @findings[:utm_present] = true
      end
    end

    puts
  end

  def enumerate_cpu_features
    puts "[2] 💻 CPU Virtualization Features"
    puts "-" * 80

    @findings[:cpu_features] = []

    if File.exist?("/proc/cpuinfo")
      cpuinfo = File.read("/proc/cpuinfo")
      flags = cpuinfo[/^flags\s*:\s*(.+)/, 1]

      if flags
        virt_features = %w[vmx svm ept npt vpid]

        virt_features.each do |feature|
          if flags.include?(feature)
            puts "✅ #{feature.upcase}: Supported"
            @findings[:cpu_features] << feature
          end
        end
      end
    elsif @platform == "macOS"
      # Check for VT-x on macOS
      if `sysctl machdep.cpu.features 2>/dev/null`.include?("VMX")
        puts "✅ VT-x (VMX): Supported"
        @findings[:cpu_features] << "vmx"
      end
    end

    if @findings[:cpu_features].empty?
      puts "⚠️  No virtualization features detected"
    end

    puts
  end

  def detect_hypervisor_type
    puts "[3] 🎯 Hypervisor Type Detection"
    puts "-" * 80

    # Check DMI/SMBIOS information
    if File.exist?("/sys/class/dmi/id/product_name")
      product = File.read("/sys/class/dmi/id/product_name").strip
      puts "Product: #{product}"

      case product
      when /QEMU/i
        puts "🎯 Confirmed: QEMU Virtual Machine"
        @findings[:hypervisor_confirmed] = "QEMU"
      when /VMware/i
        puts "🎯 Confirmed: VMware Virtual Machine"
        @findings[:hypervisor_confirmed] = "VMware"
      when /VirtualBox/i
        puts "🎯 Confirmed: VirtualBox"
        @findings[:hypervisor_confirmed] = "VirtualBox"
      end
    end

    # Check for UTM on macOS
    if @platform == "macOS" && @findings[:utm_present]
      puts "🎯 Confirmed: UTM (QEMU-based) on macOS"
      @findings[:hypervisor_confirmed] = "UTM/QEMU"

      # Try to get UTM version
      utm_version = `defaults read com.utmapp.UTM CFBundleShortVersionString 2>/dev/null`.strip
      unless utm_version.empty?
        puts "📌 UTM Version: #{utm_version}"
        @findings[:utm_version] = utm_version
      end
    end

    puts
  end

  def enumerate_virtual_devices
    puts "[4] 🔌 Virtual Device Enumeration"
    puts "-" * 80

    @findings[:virtual_devices] = []

    # Linux: Check PCI devices
    if File.exist?("/proc/bus/pci/devices") || File.exist?("/sys/bus/pci/devices")
      pci_devices = `lspci 2>/dev/null`.split("\n")

      if pci_devices.any?
        puts "Virtual devices detected:"

        pci_devices.each do |device|
          # Look for QEMU/KVM/VirtIO devices
          if device =~ /(QEMU|VirtIO|RedHat|VMware|Virtual)/i
            puts "  📍 #{device}"
            @findings[:virtual_devices] << device
          end
        end
      end
    end

    # macOS: Check IOKit devices
    if @platform == "macOS"
      iokit_devices = `ioreg -l 2>/dev/null | grep -i "qemu\|virtio" | head -10`.split("\n")

      if iokit_devices.any?
        puts "Virtual devices detected:"
        iokit_devices.each do |device|
          puts "  📍 #{device.strip}"
          @findings[:virtual_devices] << device.strip
        end
      end
    end

    if @findings[:virtual_devices].empty?
      puts "⚠️  No obvious virtual devices detected"
    end

    puts
  end

  def check_shared_memory
    puts "[5] 🧠 Shared Memory Analysis"
    puts "-" * 80

    @findings[:shared_memory] = []

    # Check for shared memory regions
    if File.exist?("/proc/self/maps")
      maps = File.read("/proc/self/maps")

      # Look for suspicious shared memory
      shared_regions = maps.scan(/^\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.+shared.+)$/i)

      if shared_regions.any?
        puts "Shared memory regions found:"
        shared_regions.flatten.uniq[0..5].each do |region|
          puts "  📍 #{region}"
          @findings[:shared_memory] << region
        end

        if shared_regions.count > 5
          puts "  ... and #{shared_regions.count - 5} more"
        end
      end
    end

    # Check for memory balloon (QEMU feature)
    if @findings[:virtualized]
      balloon_check = `lsmod 2>/dev/null | grep virtio_balloon`.strip
      if balloon_check.length > 0
        puts "✅ VirtIO balloon driver loaded (memory ballooning active)"
        @findings[:memory_balloon] = true
      end
    end

    puts
  end

  def detect_paravirt_features
    puts "[6] 🚀 Paravirtualization Features"
    puts "-" * 80

    @findings[:paravirt] = []

    # Check for VirtIO drivers
    if File.exist?("/sys/bus/virtio/devices")
      virtio_devices = Dir.glob("/sys/bus/virtio/devices/*").map { |d| File.basename(d) }

      if virtio_devices.any?
        puts "VirtIO devices:"
        virtio_devices.each do |dev|
          puts "  ✅ #{dev}"
          @findings[:paravirt] << dev
        end
      end
    end

    # Check loaded kernel modules
    if File.exist?("/proc/modules")
      modules = File.read("/proc/modules")

      paravirt_modules = %w[virtio_net virtio_blk virtio_scsi virtio_balloon virtio_console virtio_gpu]

      loaded = paravirt_modules.select { |mod| modules.include?(mod) }

      if loaded.any?
        puts "Paravirt modules loaded:"
        loaded.each do |mod|
          puts "  ✅ #{mod}"
        end
      end
    end

    puts
  end

  def enumerate_security_features
    puts "[7] 🛡️  Security Features"
    puts "-" * 80

    @findings[:security] = {}

    # Check for IOMMU
    if File.exist?("/sys/kernel/iommu_groups")
      iommu_groups = Dir.glob("/sys/kernel/iommu_groups/*")
      if iommu_groups.any?
        puts "✅ IOMMU enabled (#{iommu_groups.count} groups)"
        @findings[:security][:iommu] = true
      else
        puts "❌ IOMMU not enabled"
        @findings[:security][:iommu] = false
      end
    end

    # Check for SMEP/SMAP
    if File.exist?("/proc/cpuinfo")
      cpuinfo = File.read("/proc/cpuinfo")

      if cpuinfo.include?("smep")
        puts "✅ SMEP (Supervisor Mode Execution Prevention) available"
        @findings[:security][:smep] = true
      end

      if cpuinfo.include?("smap")
        puts "✅ SMAP (Supervisor Mode Access Prevention) available"
        @findings[:security][:smap] = true
      end
    end

    # Check for SELinux/AppArmor
    if `getenforce 2>/dev/null`.strip == "Enforcing"
      puts "✅ SELinux: Enforcing"
      @findings[:security][:selinux] = "enforcing"
    end

    if @platform == "macOS"
      # Check System Integrity Protection
      sip_status = `csrutil status 2>/dev/null`.strip
      if sip_status.include?("enabled")
        puts "✅ SIP (System Integrity Protection): Enabled"
        @findings[:security][:sip] = true
      end

      # Check for App Sandbox
      if @findings[:utm_present]
        puts "⚠️  UTM App Sandbox: Check manually with 'codesign -d --entitlements - /Applications/UTM.app'"
        @findings[:security][:app_sandbox] = "check_manually"
      end
    end

    puts
  end

  def deep_analysis
    puts "[8] 🔍 Deep Analysis Mode"
    puts "-" * 80

    puts "Performing additional checks..."
    puts

    # Check for QEMU guest agent
    if `ps aux | grep -i qemu-ga | grep -v grep`.length > 0
      puts "✅ QEMU Guest Agent running"
      @findings[:qemu_guest_agent] = true
    end

    # Check for shared clipboard
    if `ps aux | grep -i spice-vdagent | grep -v grep`.length > 0
      puts "✅ SPICE VD Agent (shared clipboard/display)"
      @findings[:spice_agent] = true
    end

    # Check for shared folders
    if `mount | grep -i 9p`.length > 0
      puts "⚠️  9p filesystem mounted (shared folders)"
      @findings[:shared_folders] = true
    end

    puts
  end

  def print_summary
    puts "=" * 80
    puts "📊 ENUMERATION SUMMARY"
    puts "=" * 80
    puts

    puts "🎯 Key Findings:"
    puts "-" * 80

    if @findings[:virtualized]
      puts "✅ Running in Virtual Machine: YES"
      puts "   Hypervisor: #{@findings[:hypervisor] || 'Unknown'}"

      if @findings[:hypervisor_confirmed]
        puts "   Confirmed Type: #{@findings[:hypervisor_confirmed]}"
      end

      if @findings[:utm_version]
        puts "   UTM Version: #{@findings[:utm_version]}"
      end
    else
      puts "❌ Not running in virtual machine (or well-hidden)"
    end

    puts

    if @findings[:virtual_devices].any?
      puts "🔌 Virtual Devices: #{@findings[:virtual_devices].count} detected"
    end

    if @findings[:paravirt].any?
      puts "🚀 Paravirt Devices: #{@findings[:paravirt].count} found"
    end

    puts

    puts "🎯 Bug Bounty Attack Surface:"
    puts "-" * 80

    attack_surface = []

    if @findings[:virtual_devices].any?
      attack_surface << "Virtual device emulation (#{@findings[:virtual_devices].count} devices)"
    end

    if @findings[:paravirt].any?
      attack_surface << "VirtIO drivers (#{@findings[:paravirt].count} drivers)"
    end

    if @findings[:shared_memory].any?
      attack_surface << "Shared memory regions"
    end

    if @findings[:qemu_guest_agent]
      attack_surface << "QEMU Guest Agent IPC"
    end

    if @findings[:spice_agent]
      attack_surface << "SPICE protocol (clipboard, display)"
    end

    if @findings[:shared_folders]
      attack_surface << "Shared filesystem (9p)"
    end

    if attack_surface.any?
      attack_surface.each { |item| puts "  🎯 #{item}" }
    else
      puts "  ⚠️  Limited attack surface detected"
    end

    puts
    puts "=" * 80
  end

  def generate_report
    report_file = "hypervisor_enum_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"

    report = {
      timestamp: Time.now.to_s,
      platform: @platform,
      findings: @findings
    }

    File.write(report_file, JSON.pretty_generate(report))
    puts "📄 Report saved: #{report_file}"
  end
end

# Main execution
if __FILE__ == $0
  require 'optparse'

  options = { deep: false }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("--deep", "Perform deep analysis") do
      options[:deep] = true
    end

    opts.on("-h", "--help", "Show help") do
      puts opts
      exit
    end
  end.parse!

  puts "✅ AUTHORIZED BUG BOUNTY RESEARCH"
  puts "   Only run on systems you own or have permission to test!"
  puts

  enumerator = HypervisorEnumerator.new
  enumerator.enumerate(deep: options[:deep])
end

#!/usr/bin/env ruby
# frozen_string_literal: true

# 🎓 EDUCATIONAL DEMONSTRATION: Sandbox Escape Protocol for Arch Linux ARM
# 📚 Purpose: Demonstrate the lack of sandboxing on Linux platforms
# ⚠️ Warning: FOR EDUCATIONAL AND AUTHORIZED SECURITY TRAINING ONLY

puts "=" * 80
puts "🔓 SANDBOX ESCAPE PROTOCOL DEMONSTRATION"
puts "🎓 Educational Purpose Only - Arch Linux ARM"
puts "=" * 80
puts

# Step 1: 🖥️ Check platform and architecture
puts "[1] 🖥️ Platform and Architecture Detection"
puts "-" * 80

platform = case RUBY_PLATFORM
when /linux/
  "Linux 🐧"
when /darwin/
  "macOS 🍎"
else
  "Other 🤷"
end

cpu_type = case RUBY_PLATFORM
when /x86_64/, /i\d86/
  "Intel 💻"
when /arm/, /aarch64/
  "ARM 💪"
when /ppc|powerpc/
  "PowerPC 🔧"
else
  "Unknown ❓"
end

is_arm = RUBY_PLATFORM =~ /arm|aarch64/
is_arm64 = RUBY_PLATFORM =~ /aarch64|arm64/
is_linux = RUBY_PLATFORM =~ /linux/

puts "Platform: #{platform}"
puts "RUBY_PLATFORM: #{RUBY_PLATFORM}"
puts "CPU Type: #{cpu_type}"
puts "Is ARM?: #{is_arm ? '✅ YES' : '❌ NO'}"
puts "Is ARM64?: #{is_arm64 ? '✅ YES' : '❌ NO'}"
puts "Is Linux?: #{is_linux ? '✅ YES' : '❌ NO'}"
puts

# Step 2: 🔍 Check sandbox availability (simulated)
puts "[2] 🔍 Sandbox Availability Check"
puts "-" * 80

# Check if /usr/bin/sandbox-exec exists (macOS Seatbelt)
sandbox_exec_exists = File.executable?("/usr/bin/sandbox-exec")
sandbox_available = sandbox_exec_exists

puts "📍 Checking for /usr/bin/sandbox-exec..."
puts "File exists?: #{sandbox_exec_exists ? '✅ YES' : '❌ NO'}"
puts
puts "Sandbox.available?: #{sandbox_available ? '✅ TRUE' : '❌ FALSE'}"
puts

if sandbox_available
  puts "✅ Sandbox IS available (macOS with /usr/bin/sandbox-exec)"
  puts "   🔒 Seatbelt sandbox will enforce restrictions"
else
  puts "❌ Sandbox NOT available (Linux or macOS without sandbox-exec)"
  puts "   ⚠️  ESCAPE CONDITION: Will fall back to unsandboxed process execution"
end
puts

# Step 3: 🚪 Demonstrate the escape mechanism
puts "[3] 🚪 Escape Mechanism Demonstration"
puts "-" * 80

if sandbox_available
  puts "On this system, the sandbox would be used:"
  puts "  📦 Sandbox.new"
  puts "  ✍️  sandbox.allow_write_temp_and_cache"
  puts "  🚫 sandbox.deny_all_network"
  puts "  ▶️  sandbox.run(*args)"
  puts
  puts "This provides Seatbelt-based isolation with:"
  puts "  ✅ File write restrictions"
  puts "  ✅ Network access control"
  puts "  ✅ System call filtering"
else
  puts "On this system, NO sandbox is used:"
  puts "  🍴 Utils.safe_fork do"
  puts "    ▶️  exec(*args)  # ← 🚪 ESCAPE POINT"
  puts "  end"
  puts
  puts "This provides NO security isolation:"
  puts "  ❌ No file write restrictions"
  puts "  ❌ No network access control"
  puts "  ❌ No system call filtering"
  puts "  ⚠️  Only basic process forking"
end
puts

# Step 4: 🧪 Demonstrate actual behavior with safe commands
puts "[4] 🧪 Live Demonstration (Safe Commands)"
puts "-" * 80

puts "Demonstrating process execution method used by Homebrew..."
puts

# Safe demonstration: Show what we can access
test_info = [
  {
    emoji: "🐧",
    name: "OS Information",
    file: "/etc/os-release",
    description: "On macOS sandbox: Could be restricted. On Linux: Full access ✅"
  },
  {
    emoji: "🏠",
    name: "Home Directory",
    file: ENV["HOME"],
    description: "On macOS sandbox: Restricted 🔒. On Linux: Full access ✅"
  },
  {
    emoji: "🔑",
    name: "SSH Directory",
    file: "#{ENV['HOME']}/.ssh",
    description: "On macOS sandbox: Blocked 🚫. On Linux: Accessible ⚠️"
  },
  {
    emoji: "📝",
    name: "Shell Config",
    file: "#{ENV['HOME']}/.bashrc",
    description: "On macOS sandbox: Restricted 🔒. On Linux: Full access ✅"
  }
]

test_info.each_with_index do |test, idx|
  puts "#{test[:emoji]} Test #{idx + 1}: #{test[:name]}"
  puts "📂 Path: #{test[:file]}"
  puts "📋 Expected behavior: #{test[:description]}"

  if File.exist?(test[:file])
    puts "   ✅ File/directory EXISTS and is accessible"
  else
    puts "   ⚠️  File/directory does not exist"
  end

  puts
end

puts "-" * 80
puts

# Step 5: ⚠️ Security implications
puts "[5] ⚠️ Security Implications for Arch Linux ARM"
puts "-" * 80

if !sandbox_available && is_arm
  puts "🚨 CRITICAL SECURITY FINDINGS:"
  puts
  puts "Your system is #{is_linux ? 'Linux 🐧' : 'non-macOS'} on ARM architecture 💪 with NO sandboxing."
  puts
  puts "When you run 'brew install <formula>', the build process has:"
  puts "  🔓 Full read access to your entire home directory"
  puts "  ✍️  Full write access anywhere you have permissions"
  puts "  🌐 Unrestricted network access (even if formula denies it)"
  puts "  🔑 Access to all environment variables (SSH keys, tokens, etc.)"
  puts "  🚀 Ability to spawn arbitrary processes"
  puts
  puts "🛡️ TRUST MODEL:"
  puts "  ✅ Only install formulae from trusted sources"
  puts "  ✅ Review formula source code before installation (brew cat <formula>)"
  puts "  ✅ Use containers for untrusted packages 🐳"
  puts "  ✅ Consider dedicated build user with limited permissions 👤"
  puts
elsif !sandbox_available
  puts "⚠️  Your #{platform} system has NO Homebrew sandboxing."
  puts "See above for security implications."
else
  puts "✅ Your macOS system HAS sandbox protection 🔒"
  puts "Build processes run with Seatbelt restrictions."
end
puts

# Step 6: 🛡️ Mitigation recommendations
puts "[6] 🛡️ Recommended Mitigations"
puts "-" * 80

mitigations = [
  "📦 Use bottles (precompiled binaries): brew install --force-bottle <formula>",
  "🔍 Review formula source: brew cat <formula> | less",
  "🐳 Use containers: docker run -it archlinux/archlinux:latest",
  "👤 Create dedicated build user: sudo useradd -m homebrew-builder",
  "🚫 Network isolation: unshare --net brew install <formula>",
  "📊 Monitor builds: strace -f brew install <formula> 2>&1 | tee build.log",
  "🔒 Limit environment: env -i HOME=/tmp brew install <formula>",
  "📦 Use bubblewrap: bwrap --ro-bind / / --tmpfs /home brew install <formula>"
]

mitigations.each_with_index do |mitigation, idx|
  puts "#{idx + 1}. #{mitigation}"
end
puts

# Step 7: 📚 Code references
puts "[7] 📚 Source Code References"
puts "-" * 80

references = [
  "📄 Sandbox availability check: Library/Homebrew/sandbox.rb:24-26",
  "🍎 macOS sandbox override: Library/Homebrew/extend/os/mac/sandbox.rb:13-15",
  "🚪 Escape point (build): Library/Homebrew/formula_installer.rb:1109-1112",
  "🚪 Escape point (postinstall): Library/Homebrew/formula_installer.rb:1349-1352",
  "🍴 Process isolation: Library/Homebrew/utils/fork.rb:41-125",
  "💪 ARM detection: Library/Homebrew/hardware.rb:161-170",
  "🐧 Linux CPU info: Library/Homebrew/extend/os/linux/hardware/cpu.rb:170-173"
]

references.each do |ref|
  puts "• #{ref}"
end
puts

# Final summary
puts "=" * 80
puts "✅ DEMONSTRATION COMPLETE"
puts "=" * 80
puts
puts "🎯 KEY TAKEAWAY:"
puts "The 'sandbox escape' on Linux is not a vulnerability or exploit."
puts "It is an architectural design decision where Homebrew relies on:"
puts "  1️⃣ User trust in formula sources"
puts "  2️⃣ Operating system security controls"
puts "  3️⃣ Community review and vetting"
puts
puts "🔒 For maximum security on Arch Linux ARM:"
puts "  → Only install from official Homebrew taps 🏷️"
puts "  → Review third-party formulae before installation 🔍"
puts "  → Use additional OS-level isolation when needed 🛡️"
puts
puts "=" * 80
puts
puts "📖 For full documentation, read:"
puts "   less /home/user/brew/SANDBOX_ESCAPE_PROTOCOL_EDU.md"
puts "   less /home/user/brew/QUICK_REFERENCE.md"
puts
puts "=" * 80

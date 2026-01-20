# frozen_string_literal: true

RSpec.describe OS do
  describe "::kernel_version" do
    it "is not NULL" do
      expect(described_class.kernel_version).not_to be_null
    end
  end

  describe "::kernel_name" do
    it "returns Linux on Linux", :needs_linux do
      expect(described_class.kernel_name).to eq "Linux"
    end

    it "returns Darwin on macOS", :needs_macos do
      expect(described_class.kernel_name).to eq "Darwin"
    end
  end

  describe "PATH_OPEN" do
    it "is set to /usr/bin/open on macOS", :needs_macos do
      expect(OS::PATH_OPEN).to eq "/usr/bin/open"
    end

    it "is set to a browser on Linux", :needs_linux do
      expect(OS::PATH_OPEN).to be_a(String)
      expect(OS::PATH_OPEN).not_to be_empty
      # Should be either a full path or a command name
      expect(OS::PATH_OPEN).to match(%r{^(/|[a-z-]+$)})
    end

    it "uses wslview on WSL if available", :needs_linux do
      skip "Not running on WSL" unless OS::Linux.wsl?

      # If wslview is in PATH, PATH_OPEN should use it
      if which("wslview")
        expect(OS::PATH_OPEN).to match(/wslview/)
      end
    end

    it "falls back to available browser on Linux", :needs_linux do
      skip "Running on WSL" if OS::Linux.wsl?

      # PATH_OPEN should be set to one of the known browsers
      known_browsers = %w[xdg-open firefox chromium chromium-browser google-chrome]
      expect(known_browsers).to include(OS::PATH_OPEN)
    end
  end
end

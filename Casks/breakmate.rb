# Auto-updated by .github/workflows/macos_release.yml on every release.
cask "breakmate" do
  version "1.12.0"
  sha256 "1891a7df8d62ab2a618f37ba77fdda3d2231c8167a6f625ecb3681a0954ecf5f"

  url "https://github.com/bijithpn/standup/releases/download/v#{version}/BreakMate-Installer.dmg"
  name "BreakMate"
  desc "Break and wellness companion for desktop"
  homepage "https://github.com/bijithpn/standup"

  auto_updates true

  app "BreakMate.app"

  # The app is not notarized; drop the quarantine flag so Gatekeeper does not block it.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/BreakMate.app"]
  end

  uninstall quit: "com.bijith.breakmate"

  zap trash: [
    "~/Library/Application Support/com.bijith.breakmate",
    "~/Library/Caches/com.bijith.breakmate",
    "~/Library/Preferences/com.bijith.breakmate.plist",
    "~/Library/Saved Application State/com.bijith.breakmate.savedState",
  ]
end

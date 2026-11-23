# Auto-updated by .github/workflows/macos_release.yml on every release.
cask "breakmate" do
  version "1.14.0"
  sha256 "4af6be4ec95f2a069baae9cb18445fca3eba6f8fc5c6414e1a49f4711d4b49b7"

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

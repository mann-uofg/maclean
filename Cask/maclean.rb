cask "maclean" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/maclean/maclean/releases/download/#{version}/MacleanApp.zip"
  name "Maclean"
  desc "Menu bar app to temporarily block keyboard and mouse input for cleaning"
  homepage "https://github.com/maclean/maclean"

  app "MacleanApp.app"

  # Explanation of post-install instructions natively prompted in Homebrew Cask format.
  caveats <<~EOS
    Maclean relies on deep input-blocking APIs through CGEventTap to function correctly.
    You MUST grant Accessibility permission upon first launch or it will fail silently.
    
    To resolve permissions manually, visit:
        System Settings -> Privacy & Security -> Accessibility
    
    Ensure "MacleanApp" is fully toggled ON.
  EOS

  # Wipe everything when users want a clean uninstall.
  zap trash: [
    "~/Library/Preferences/com.maclean.MacleanApp.plist",
    "~/Library/Saved Application State/com.maclean.MacleanApp.savedState",
  ]
end

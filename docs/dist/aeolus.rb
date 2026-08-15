# Каск для tap-репозитория moverq1337/homebrew-aeolus.
# При релизе: обновить version и sha256 (печатает Scripts/release.sh).
cask "aeolus" do
  version "0.3.0"
  sha256 "3cea44af7719d869e30a104735132a524b0ab62768571dbaaafba6d72c8d585b"

  url "https://github.com/moverq1337/Aeolus/releases/download/v#{version}/Aeolus-#{version}.zip"
  name "Aeolus"
  desc "Dynamic Island for the MacBook notch: media and battery, nothing else"
  homepage "https://github.com/moverq1337/Aeolus"

  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "Aeolus.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Aeolus.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/io.github.moverq1337.aeolus.plist",
  ]
end

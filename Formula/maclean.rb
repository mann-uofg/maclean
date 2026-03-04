class Maclean < Formula
  desc "macOS Input Blocker — temporarily disable keyboard/mouse for physical cleaning"
  homepage "https://github.com/mann-uofg/maclean"
  url "https://github.com/mann-uofg/maclean/archive/refs/tags/1.0.0.tar.gz"
  sha256 "22f741b4f50edfde24e25e7b41268cc00574184745b76ad9434f2a01a718ac61"
  license "MIT"

  # Requires macOS Tahoe (26.3) or higher for modern Swift concurrency and SwiftUI MenuBarExtra support
  depends_on macos: :tahoe

  def install
    # Build the CLI executable purely through SPM (Whole-module optimization for minimum size)
    system "swift", "build", "--disable-sandbox", "--configuration", "release", "--product", "maclean"

    # Install the compiled output to Homebrew bin
    bin.install ".build/release/maclean"

    # Install the troff man page to the correct Homebrew man1 directory
    man1.install "man/maclean.1"
  end

  test do
    # Simple version check test since CGEventTap cannot be validated inside Homebrew's restricted CI sandbox.
    assert_match "maclean version 1.0.0", shell_output("#{bin}/maclean --version")
  end
end

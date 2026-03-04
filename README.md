# Maclean 🧹

> A production-grade macOS application and CLI tool that temporarily blocks keyboard and mouse input so you can physically clean your Mac without accidental keypresses.

![maclean-badge-version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![maclean-badge-macos](https://img.shields.io/badge/macOS-Tahoe%2B-lightgrey.svg)
![maclean-badge-license](https://img.shields.io/badge/license-MIT-green.svg)

## Installation

### Via Homebrew (Recommended)

You can install the CLI tool via Homebrew.

```bash
brew install maclean
```

### Manual Install from Source

Ensure you have Xcode 18 or the Swift 6.2+ toolchain installed.

```bash
git clone https://github.com/maclean/maclean.git
cd maclean
swift build --configuration release
cp .build/release/maclean /usr/local/bin/
```

## Setup & Permissions

Maclean operates at the OS input layer and relies heavily on the `CGEventTap` CoreGraphics API.
To function, **Maclean requires Accessibility permissions**.

1. Open **System Settings** -> **Privacy & Security** -> **Accessibility**
2. Ensure the toggle next to **Maclean** (or your Terminal app if using the CLI for the first time) is switched **ON**.

*If Maclean fails to block input or exits unexpectedly, verify these permissions first.*

## Usage

### CLI Usage

The `maclean` CLI offers a clean, spinner-based terminal UI while blocking input. It defaults to 60 seconds if no arguments are provided.

```bash
# Block for exactly 60 seconds (default)
maclean

# Block for exactly 30 seconds
maclean 30

# Block indefinitely until a Touch ID verify succeeds
maclean touch

# Block for 120 seconds OR until Touch ID verify (whichever comes first)
maclean 120 touch
```

**How to Stop Early:**

- Press `Ctrl+C` in your terminal.
- Use Touch ID (if enabled).
- Press the global emergency chord: `Left Shift` + `Right Shift` + `Escape`.

## Architecture & OS-Level Safety

Maclean is designed from the ground up to prevent OS-level lockouts while maintaining a near-zero memory footprint.

- **Memory Footprint**: The `MacleanCore` engine uses meticulous ARC discipline. The CLI binary is less than 2 MB.
- **Single-Lock Discipline**: The core blocking state is isolated into a Swift `actor` to prevent data races and deadlocks.
- **Priority Protocol**: The hot-path callback runs on a dedicated, high-priority thread utilizing `os_unfair_lock` to entirely sidestep priority inversion.
- **Watchdog Failsafe**: A background heartbeat mechanism actively monitors the Maclean process. If the application crashes or hangs mid-session, the watchdog will immediately sever the process, forcing the macOS kernel to reap the event tap and restore input instantly.

### Unblock Mechanisms

- **Time-based**: Input restores automatically when the timer reaches zero.
- **Touch ID**: A biometric unblock via `LocalAuthentication`.
- **Safe Key Chord (Emergency)**: If all else fails, you can press **Left Shift + Right Shift + Escape** simultaneously to force the kernel tap to release immediately.

## Troubleshooting

- **App crashed while blocking**: The macOS window server immediately severs broken Mach ports. The kernel will restore your input automatically.
- **Permission Denied**: Open System Settings -> Privacy & Security -> Accessibility, remove Maclean using the `-` button, and add it back manually using `+`.
- **Touch ID Unavailable**: Make sure your Mac's lid is open and Touch ID is fully enrolled via System Settings.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture deep-dives and development guidelines. Always verify TSan and ASan locally before opening a pull request.

## License

MIT License. See [LICENSE](LICENSE) for details.

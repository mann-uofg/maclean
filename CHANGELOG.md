# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Initially Released

### Added

- Complete `MacleanCore` Swift Swift Package Manager engine for OS-wide kernel tap input blocking
- Safe blocking state actor `BlockingSessionActor` mapping concurrency boundaries
- Custom lock-free event tap bridging with high QoS priority
- Un-killable background crash watchdog safety guard
- Combined biometric + timeout based `UnlockCoordinator`
- Hardware Key Chord fallbacks correctly integrated into fast-paths
- Fully standalone `MacleanCLI` terminal tool with timer outputs
- Comprehensive `MacleanApp` SwiftUI-based Menu Bar GUI for configuring preferences manually
- Homebrew formula and Cask configurations
- `man/maclean.1` Troff groff specifiers for OS `man` viewing out-of-the-box

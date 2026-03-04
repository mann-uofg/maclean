# Contributing to Maclean

Thank you for contributing! `maclean` is an OS-level utility that taps extremely deep into the macOS kernel.
Contributions must adhere to the highest standards of memory efficiency and OS-level robustness. A single bug
in `MacleanCore` could permanently lock a user's machine until forced reboot.

## Architecture

- **`MacleanCore`**: A shared Swift Package Manager library serving as the core blocking engine.
- **`BlockingSessionActor`**: Owns all mutable blocking state, serializing state transitions.
- **`EventTapManager`**: C-based event tap bridge running on a dedicated run-loop thread.
- **`MacleanCLI`**: The Homebrew-installable command line tool.

## Setting Up

1. `git clone https://github.com/maclean/maclean.git`
2. `swift build --configuration release`

## Code Style

- Use `.swiftlint.yml` to validate style. CI will block your PR if SwiftLint fails.
- Run `swiftlint` locally before committing.

## Memory Efficiency Guidelines

`maclean` is a background utility. It must have a negligible memory footprint at all times.

- **Active blocking target**: Memory usage must not exceed **25 MB RSS**.
- **Run Instruments**: Use XCode Instruments (Leaks + Allocations) to verify zero leaks before submitting a PR.
- **No Tap Allocations**: The `CGEventTap` callback must allocate zero objects on the hot path.
- **Value Types**: Prefer `struct` and `enum` over reference types in `MacleanCore`.
- **Closure Captures**: Annotate every closure capture list explicitly (`[weak self]`). Never implicitly capture `self` in `MacleanCore`.

## OS-Level Rules (Strictly Enforced)

1. **Lock Ordering**: Never hold two locks simultaneously. Follow the strict single-lock discipline using `os_unfair_lock` (never `NSLock`) inside the hot paths, and isolate state using the `BlockingSessionActor`.
2. **Actor Boundaries**: Ensure all C-callbacks bridge into the Actor world asynchronously without permanently suspending or blocking the caller.
3. **No `fatalError()`**: Never use string-based errors or `fatalError()` in production code paths. Use the strongly-typed `MacleanError`.
4. **Kernel Resource Cleanup**: Every `CFMachPort` created for the event tap MUST be paired with a `CFRelease` or `CFMachPortInvalidate` using `defer` logic to prevent zombie taps.

## Testing Guidelines

Run TSan and ASan locally before opening a pull request:

```bash
swift test --sanitize thread
swift test --sanitize address
```

All OS-level tests, including 100-cycle deadlock stress tests and signal handling teardown, must pass concurrently on CI.

## Release Process

1. Merge approved PRs entirely to `main`.
2. Update `CHANGELOG.md` exactly following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.
3. Tag the new release (`vX.Y.Z`).
4. Update `Formula/maclean.rb` shasums.

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.

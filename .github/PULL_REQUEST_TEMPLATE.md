# Description

Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context.

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)

## OS-Level Safety Checklist

- [ ] My code strictly follows the single-lock discipline (`os_unfair_lock`) or uses the `BlockingSessionActor`.
- [ ] I have verified that all `CGEventTap` hot-path callbacks allocate ZERO objects to prevent latency.
- [ ] I have verified there are no memory leaks locally using Xcode Instruments.
- [ ] I ran `swift test --sanitize thread` and `swift test --sanitize address` locally, and they passed.
- [ ] I verified that all initialized kernel resources (`Mach port`) use `defer` for bulletproof cleanup.

## Additional Documentation Checklist

- [ ] I have updated the `CHANGELOG.md` exactly following Keep A Changelog format.
- [ ] `maclean.rb` homebrew formulas were bumped if this is a final release candidate.
- [ ] I added inline `///` DocC documentation for any new Swift core features.

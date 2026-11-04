## [0.1.0] - 2026-11-04

### Added

- Rails configuration generator and explicit development tunnel tasks.
- Quiet offline retries, configurable cloudflared log levels and separate logs.
- Installation guidance without automatic executable installation.
- Connector readiness and signed local/public application diagnostics.
- Secure temporary tokens, per-app locking and bounded child shutdown.
- Local quality checks and tag-triggered GitHub Actions publishing.

### Changed

- Release preparation runs from main, checks for duplicate tags, runs local
  checks, commits version and changelog updates, and pushes the branch and tag.
- The first release can use the existing version and changelog without a version
  bump or empty commit. Publishing runs in GitHub Actions after the tag is pushed.

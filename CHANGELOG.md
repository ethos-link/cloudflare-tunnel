# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-11-04


### Added

- migrate Cloudflare Tunnel to Ethos Gemkit




### Changed

- remove the verified legacy implementation

- pin verified release artifact and tag safeguards

- reduce the gem to shared workflow callers

- publish reviewed release PRs through gemkit

- pin the toolkit cache verification fix

- adopt the published Gemkit 0.1.0 release




### Fixed

- activate the bundle before loading gemkit tasks

- ignore Bundler's CI dependency cache



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

### Fixed

- Use a shared credentials action with an explicit RubyGems owner for trusted
  publishing of both first and subsequent releases.

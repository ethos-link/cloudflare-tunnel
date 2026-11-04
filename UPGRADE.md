# Upgrade notes

## Unreleased

Ruby 4.0 or newer is required. Rails integration requires host-installed Rails
8.1 or newer within Rails 8. Railties is optional: core runner and probe entry
points work without it. Applications that load the core before Rails should
explicitly require `cloudflare/tunnel/rails` after installing compatible Rails.

Development uses a pinned ethos-gemkit dependency. Release metadata changes now
use ordinary feature-branch PRs, followed by an annotated tag after merging.
The shared RubyGems workflow requires the trusted-publisher registration described
in the toolkit README before its first live release.

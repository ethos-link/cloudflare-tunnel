# Upgrade notes

## Unreleased

Ruby 4.0 or newer is required. Rails integration requires host-installed Rails
8.1 or newer within Rails 8. Railties is optional: core runner and probe entry
points work without it. Applications that load the core before Rails should
explicitly require `cloudflare/tunnel/rails` after installing compatible Rails.

Development uses a pinned ethos-gemkit dependency. Run `release:prepare` from
current main to create a verified release PR.
Merging that PR automatically tags and publishes its reviewed merge commit.
The shared RubyGems workflow requires the trusted-publisher registration described
in the toolkit README before its first live release.

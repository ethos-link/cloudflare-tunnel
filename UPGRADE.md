# Upgrade notes

## Unreleased

### Shared gem development and runtime baseline

Ruby 4.0 or newer is required. Rails integrations support Rails 8; retain any
higher documented minimum for this gem. Install Rails in the host application
when using framework features. Development uses an immutable ethos-gemkit Git revision.
`ETHOS_GEMKIT_PATH` may override it for local toolkit work.

Railties is no longer installed as a runtime dependency. Plain Ruby entry points
work without it. For an application that loads the core before Rails, explicitly
require `cloudflare/tunnel/rails` after installing compatible Rails.


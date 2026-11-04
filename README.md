# Cloudflare Tunnel

Run a remotely-managed Cloudflare tunnel alongside a Rails development server.
Offline startup and connection loss stay quiet and do not stop the server or
jobs. The gem supervises an existing `cloudflared` executable; it never installs,
downloads or updates it, creates a tunnel, or changes DNS.

Requires Ruby 4.0+ and a POSIX host (Linux or macOS). Rails integration
requires host-installed Rails 8.1+. Runner and probe classes can load without Rails.
MIT licensed; maintained by [Ethos Link](https://www.ethos-link.com).
This is an independent integration.

## Rails setup

Add to the development group:

```ruby
group :development do
  gem "cloudflare-tunnel", "~> 0.1"
end
```

```sh
bundle install
bin/rails generate cloudflare_tunnel:install \
  --hostname=devel.example.com --port=3000 --metrics-port=20241
```

The generator creates `config/initializers/cloudflare_tunnel.rb` and adds
`tunnel: bin/rails cloudflare_tunnel:start` to `Procfile.dev`.

Install the executable yourself using [Cloudflare's instructions](https://developers.cloudflare.com/tunnel/downloads/).
When missing, the start task prints that link once and stays idle so Foreman
keeps other services running. The check task reports it and exits with failure.

In Cloudflare, configure a remotely-managed tunnel's published application
hostname to use `http://localhost:3000` (match your Rails port). Store its
connector token with `bin/rails credentials:edit`:

```yaml
cloudflare:
  tunnel:
    token: YOUR_TUNNEL_TOKEN
```

`TUNNEL_TOKEN` overrides credentials. Tokens use temporary files with mode `0600`,
stay out of command arguments and diagnostics, and are removed on normal exit,
INT and TERM. A forced OS kill cannot run cleanup; remove abandoned
`cloudflare-tunnel-*.token` files from your OS temporary directory if needed.

```sh
bin/dev
# In a second terminal, after Rails and the tunnel are running:
bin/rails cloudflare_tunnel:check
```

Adding the gem or booting Rails never starts a tunnel. Only the explicit start
task does. Tasks refuse to run outside development. The diagnostic middleware
is installed only in development. The generated initializer guards against the
gem being excluded from other Bundler groups.

## Configuration

```ruby
if Rails.env.development?
  Cloudflare::Tunnel.configure do |config|
    config.hostname = "devel.example.com"
    config.origin = "http://localhost:#{ENV.fetch('PORT', '3000')}"
    config.metrics_port = 20241
    config.log_level = :error
    config.log_path = "log/cloudflare-tunnel.log"
    config.retry_interval = 30
  end
end
```

| Option | Default | Purpose |
| --- | --- | --- |
| `hostname` | required | Bare public hostname configured in Cloudflare |
| `origin` | `http://localhost:$PORT` (`3000` otherwise) | Expected Rails origin; change Cloudflare's origin setting separately |
| `metrics_port` | `20241` | Readiness/metrics port bound to `127.0.0.1`; choose a distinct port for every concurrent app |
| `log_level` | `:error` | Native cloudflared level: `:debug`, `:info`, `:warn`, `:error`, `:fatal` |
| `log_path` | `log/cloudflare-tunnel.log` | Append connector output here, relative to Rails root; `nil` discards it |
| `retry_interval` | `30` | Seconds before restarting an exited connector |
| `shutdown_timeout` | `5` | Seconds after TERM before killing a stuck child |
| `check_timeout` | `5` | HTTP connection/read/write timeouts, per diagnostic request |
| `executable` | `cloudflared` | Name on PATH or an explicit filesystem path |
| `enabled` | true | False when `TUNNEL` is `0`, `false`, `off` or `no`; configurable explicitly |
| `token` | lazy Rails credentials / `TUNNEL_TOKEN` | String or callable; keep real tokens out of initializers |

The connector handles its own reconnections. If it exits, the supervisor retries
after `retry_interval`, without recurring terminal messages. Disabled tunnels,
missing credentials and invalid configurations print one actionable message and
stay idle. Fix configuration and restart. The check fails for those states.

Use `TUNNEL=0 bin/dev` to disable the connector. Use your local Rails URL offline.
OAuth callbacks and provider requests still need internet. Turnstile behavior
remains application-owned.

The native log level filters cloudflared messages. Connector output stays out of
Rails logs and recurring Foreman output. Set `log_path = nil` to discard it.
Ignore `log/` and `tmp/` in Git; appended logs need normal local cleanup. Debug
logs may include request details; enable that level only while diagnosing.

A per-app file lock prevents two gem-managed connectors in the same working
directory. Stop older Docker or system-service connectors for that tunnel
yourself. Other working directories can still run replicas and receive traffic.

## Diagnostics

`bin/rails cloudflare_tunnel:check` returns `0` only when all checks pass:

1. Configuration, executable availability and token presence.
2. The local Rails origin returns a fresh signed probe response.
3. The connector's `/ready` endpoint reports an active Cloudflare connection.
4. HTTPS on the public hostname returns the expected response from this app.

The development-only `/.well-known/cloudflare-tunnel?nonce=…` probe uses an HMAC
with a purpose-specific key derived from Rails' secret key base and returns
`Cache-Control: no-store`. It creates no records and exposes no credentials.
Fresh nonces prevent stale cached health pages passing the check. The signature
identifies the application's key, not a particular machine sharing that key.
The configured metrics port must belong to this connector.

Failures identify the layer and return `1`, including offline failures. The check
does not start a connector or change configuration. Redirects, Access login pages
and incorrect origins/app keys fail. Executable availability alone does not
validate the token; the running connector and end-to-end checks establish that.
Authentication errors remain in the separate connector log. No Cloudflare
management API token is required.

References: [run parameters](https://developers.cloudflare.com/tunnel/reference/run-parameters/)
and [readiness example](https://developers.cloudflare.com/tunnel/guides/kubernetes/).

## Development

Run `bin/setup` to install development dependencies, then `bin/ci` to run
Minitest, Standard Ruby, the gem build and changelog generation. Tests control
connector executables and HTTP boundaries; they need no Cloudflare account or
internet once dependencies are installed.

Development defaults come from the published `ethos-gemkit` 0.1.0 gem. Workflow
callers pin the same release commit. `bin/ci` runs the shared lint, test, package
and git-cliff checks.

## Releases

Configure **cloudflare-tunnel → Trusted publishers** on RubyGems before its
first release through Gemkit:

| RubyGems field | Value |
|---|---|
| Repository owner | `ethos-link` |
| Repository name | `cloudflare-tunnel` |
| Workflow filename | `release.yml` |
| Environment | `rubygems` |
| Workflow Repository Owner | `ethos-link` |
| Workflow Repository Name | `ethos-gemkit` |

The Workflow Repository fields are required because the publishing workflow lives
in Gemkit. Gemkit's own trusted-publisher registration does not authorize Tunnel.

After setup, start from clean, up-to-date main and run:

```sh
git switch main
git pull --ff-only
bundle install
bundle exec rake 'release:prepare[patch]'
```

Use `minor`, `major` or an explicit version instead of `patch` when appropriate.
The task creates `chore/release-vVERSION`, updates the version, changelog and
lockfile, runs all checks, commits with hooks enabled, pushes the branch and
opens a release PR. Review the PR and any upgrade notes before merging.

**Merging that release PR builds, tags and publishes the gem automatically.**
The shared workflow uses the exact reviewed merge commit and creates the GitHub
release after publication. The normal flow needs no manual tag command.

If credential setup reports `No trusted publisher configured for this workflow`
and `gem push` was skipped, correct the RubyGems settings above and rerun only
failed jobs in the original workflow run:

```sh
gh run rerun RUN_ID --repo ethos-link/cloudflare-tunnel --failed
```

The verified artifact and existing tag are reused. Do not prepare a new release,
bump the version or replace the tag to recover from this authentication failure.

For failed release notes, rerun only failed jobs in the original workflow run;
the same artifact is reused without republishing. The
[toolkit release guide](https://github.com/ethos-link/ethos-gemkit#releasing-a-gem)
covers CLI/hook prerequisites, publisher fields, environment permissions,
preparation failures and upload reconciliation.

GitLab sync has no caller because no target URL is configured.

## More from Ethos Link

Cloudflare Tunnel is maintained by [Ethos Link](https://www.ethos-link.com),
the software company behind Reviato and Nuntio. We build business products and
share open-source software.

- [Reviato — customer feedback and review analytics](https://www.reviato.com):
  Collect private guest feedback and explore recurring themes in public reviews.
  Hotels, restaurants and other local businesses can read the original customer
  comments, track feedback and decide what needs attention.
- [Nuntio — social media scheduling and publishing](https://www.nuntiohq.com):
  Prepare social posts ahead of time, adapt captions and media for each channel,
  and bring drafts, team review, scheduling and publishing outcomes into one
  workspace.

Explore [Ethos Link's products](https://www.ethos-link.com/products) and
[open-source projects](https://www.ethos-link.com/opensource).

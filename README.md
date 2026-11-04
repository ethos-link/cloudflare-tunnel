# Cloudflare Tunnel

Run a remotely-managed Cloudflare tunnel alongside a Rails development server.
Offline startup and connection loss stay quiet and do not stop the server or
jobs. The gem supervises an existing `cloudflared` executable; it never installs,
downloads or updates it, creates a tunnel, or changes DNS.

Requires Ruby 4.0+, Rails 8.1 and a POSIX host (Linux or macOS).
MIT licensed; maintained by [Ethos Link](https://www.ethos-link.com).
This is an independent integration.

## Rails setup

Add to the development group (once published):

```ruby
group :development do
  gem "cloudflare-tunnel", "~> 0.1"
end
```

Before the first release, use the GitHub repository pinned to a reviewed commit,
or a local `path:` dependency while developing the gem.

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

## Development and releases

Run `bin/setup`, then `bin/ci` for Minitest, Standard Ruby, gem build and git-cliff
generation. Tests control connector executables and HTTP boundaries; they need
no Cloudflare account or internet once dependencies are installed. Use
`bundle exec rake -T` to list tasks. Branch/PR Actions runs commitlint only.
All other checks run locally and in the tag-triggered release workflow.

Prepare a new version from a clean `main` working tree:

```sh
bundle exec rake 'release:prepare[patch]' # minor, major or a newer X.Y.Z
```

The task checks for existing local and remote tags, updates the changelog and
version, runs `bin/ci`, commits with `LEFTHOOK=0`, creates an annotated tag, and
pushes the branch followed by the tag. This matches Indexmap and Crawlscope;
release commits bypass the hook that normally blocks direct commits to main.

For the first `0.1.0` release, whose version and changelog are already present,
run `bundle exec rake 'release:prepare[0.1.0]'`. With no existing release tags,
the task accepts the current version, verifies its changelog entry, runs checks,
and pushes the branch and tag without creating an empty commit. Subsequent
releases require a newer version. `release:tag` remains available to tag an
already prepared version on clean, synchronized `main`.

`rake release` refuses local publication. A `v*` tag triggers
`.github/workflows/release.yml`: verify main ancestry and version, run `bin/ci`,
publish to RubyGems and create a GitHub release with release notes and the gem
attached.

Before the first tag, configure a RubyGems pending trusted publisher for gem
`cloudflare-tunnel`, owner `ethos-link`, repository `cloudflare-tunnel`, workflow
`release.yml`, environment `rubygems`. Configure the matching GitHub environment
and release restrictions. Publishing uses OIDC with the RubyGems credentials
action used by Indexmap and Crawlscope. No publishing token is stored here.
Creating this workflow does not register the publisher or publish a release.

## More from Ethos Link

Cloudflare Tunnel is maintained by [Ethos Link](https://www.ethos-link.com),
the software company behind Reviato and Nuntio. We build business products and
share open-source tools for developers working with Ruby and Rails.

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

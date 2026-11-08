# Cloudflare Tunnel

Supervise a host-installed cloudflared connector alongside Rails development.

For Rails developers exposing a local development server through an existing tunnel. The gem does not install cloudflared, create tunnels or configure DNS. Rails tasks refuse to run outside development.

[Project and full documentation](https://www.ethos-link.com/opensource/cloudflare-tunnel) · [RubyGems](https://rubygems.org/gems/cloudflare-tunnel) · [Changelog](CHANGELOG.md)

## Requirements

Ruby 4.0 or newer on a POSIX host (Linux or macOS). Rails integration requires host-installed Rails 8.1 or newer. Install `cloudflared` separately and create a remotely-managed Cloudflare tunnel.

## Installation

```sh
gem install cloudflare-tunnel
```

## Quick start

```sh
bundle add cloudflare-tunnel --group development
bin/rails generate cloudflare_tunnel:install --hostname=devel.example.com --port=3000 --metrics-port=20241
```

The generator creates `config/initializers/cloudflare_tunnel.rb` and a tunnel entry in `Procfile.dev`. Before `bin/dev`, configure the Cloudflare hostname and origin and save the connector token as described below. Booting Rails alone never starts a connector.

See the [full documentation](https://www.ethos-link.com/opensource/cloudflare-tunnel) for configuration, workflows, operational details and limitations.
For existing installations, read [UPGRADE.md](UPGRADE.md).

## Development and releases

Use published [Ethos Gemkit](https://github.com/ethos-link/ethos-gemkit) for shared
tooling. Keep the exact Gemfile version and workflow commit pins on the same release.

```sh
bundle install
bundle exec lefthook install
bundle exec rake verify
```

Tests use controlled local fixtures and need no service account.
Release preparation, publication, registry setup and recovery are documented
in the [Gemkit release guide](https://www.ethos-link.com/opensource/ethos-gemkit#releasing-a-gem).

## About Ethos Link

[Ethos Link](https://www.ethos-link.com) is a software company founded by
[Paulo Fidalgo](https://www.fidalgo.pt). We publish these Ruby tools alongside
our business products:

- [Reviato](https://www.reviato.com): private customer feedback and public review analysis.
- [Nuntio](https://www.nuntiohq.com): prepare, review and schedule social posts.
- [EthosPlaces](https://www.ethos.place): find places, opening hours and contact details.

## License

MIT. See [LICENSE.txt](LICENSE.txt).

# frozen_string_literal: true

require_relative "lib/cloudflare/tunnel/version"

Gem::Specification.new do |spec|
  spec.name = "cloudflare-tunnel"
  spec.version = Cloudflare::Tunnel::VERSION
  spec.authors = ["Paulo Fidalgo", "Ethos Link"]
  spec.email = ["devel@ethos-link.com"]

  spec.summary = "Quiet, offline-tolerant Cloudflare tunnels for Rails development"
  spec.description = "Supervise host-installed cloudflared with Rails configuration, quiet retries, secure token handling, and end-to-end diagnostics."
  spec.homepage = "https://github.com/ethos-link/cloudflare-tunnel"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ethos-link/cloudflare-tunnel"
  spec.metadata["changelog_uri"] = "https://github.com/ethos-link/cloudflare-tunnel/blob/main/CHANGELOG.md"

  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) { Dir["lib/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"].select { |file| File.file?(file) } }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 8.1", "< 9"
  spec.add_dependency "net-http", "~> 0.9"
  spec.add_dependency "openssl", ">= 3.3", "< 5"
end

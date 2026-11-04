# frozen_string_literal: true

namespace :cloudflare_tunnel do
  desc "Run the optional development tunnel with quiet offline retries"
  task start: :environment do
    abort "cloudflare_tunnel:start is only available in development" unless Rails.env.development?
    Cloudflare::Tunnel::Runner.new(Cloudflare::Tunnel.configuration).run
  end

  desc "Check configuration, connector, local origin and public app identity"
  task check: :environment do
    abort "cloudflare_tunnel:check is only available in development" unless Rails.env.development?
    exit(Cloudflare::Tunnel::Check.new(Cloudflare::Tunnel.configuration).run ? 0 : 1)
  end
end

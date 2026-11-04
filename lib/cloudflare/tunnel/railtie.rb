# frozen_string_literal: true

module Cloudflare
  module Tunnel
    class Railtie < Rails::Railtie
      initializer "cloudflare_tunnel.defaults", before: :load_config_initializers do |app|
        Cloudflare::Tunnel.configure do |config|
          config.root = app.root
          config.token = -> { ENV["TUNNEL_TOKEN"] || app.credentials.dig(:cloudflare, :tunnel, :token) }
          config.probe_secret = -> { app.key_generator.generate_key("cloudflare-tunnel/probe", 32) }
        end
      end

      initializer "cloudflare_tunnel.probe", after: :load_config_initializers do |app|
        if Rails.env.development?
          app.middleware.use Probe, secret: Cloudflare::Tunnel.configuration.probe_secret
        end
      end

      rake_tasks do
        load File.expand_path("../tasks/tunnel.rake", __dir__)
      end
    end
  end
end

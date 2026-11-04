# frozen_string_literal: true

require "rails/generators"

module Cloudflare
  module Tunnel
    module Generators
      class InstallGenerator < Rails::Generators::Base
        namespace "cloudflare_tunnel:install"
        source_root File.expand_path("templates", __dir__)
        desc "Configure a remotely-managed development tunnel; never installs cloudflared"
        class_option :hostname, type: :string, required: true, desc: "Public development hostname"
        class_option :port, type: :numeric, default: 3000, desc: "Local Rails port"
        class_option :metrics_port, type: :numeric, default: 20241, desc: "Unique loopback connector metrics port"

        def create_configuration
          template "initializer.rb.tt", "config/initializers/cloudflare_tunnel.rb"
        end

        def configure_procfile
          entry = "tunnel: bin/rails cloudflare_tunnel:start\n"
          if File.exist?(File.join(destination_root, "Procfile.dev"))
            content = File.read(File.join(destination_root, "Procfile.dev"))
            if content.match?(/^tunnel:\s+bin\/tunnel\s*$/)
              gsub_file "Procfile.dev", /^tunnel:\s+bin\/tunnel[^\n]*\n?/, entry
            elsif content.match?(/^tunnel:/)
              say "Existing tunnel entry retained; use: #{entry.strip}"
            else
              append_to_file "Procfile.dev", "\n#{entry}"
            end
          else
            create_file "Procfile.dev", entry
          end
        end

        def instructions
          say "Set cloudflare.tunnel.token with bin/rails credentials:edit."
          say "In Cloudflare, route #{options[:hostname]} to http://localhost:#{options[:port]}."
          say "Install cloudflared yourself if needed: #{Cloudflare::Tunnel::INSTALL_URL}"
          say "Start bin/dev, then run bin/rails cloudflare_tunnel:check."
        end
      end
    end
  end
end

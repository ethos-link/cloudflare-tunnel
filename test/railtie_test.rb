# frozen_string_literal: true

require "test_helper"
require "open3"

class RailtieTest < Minitest::Test
  def test_development_loads_probe_and_tasks_without_starting_a_connector
    script = <<~'RUBY'
      require "rails"
      require "action_controller/railtie"
      require "cloudflare-tunnel"
      require "rack/mock"
      class ProbeApp < Rails::Application
        config.eager_load = false
        config.secret_key_base = "probe-app-secret"
        config.logger = Logger.new(File::NULL)
        config.hosts = []
      end
      Rails.application.initialize!
      Rails.application.load_tasks
      abort "Missing task" unless Rake::Task.task_defined?("cloudflare_tunnel:start") && Rake::Task.task_defined?("cloudflare_tunnel:check")
      nonce = "a" * 64
      response = Rack::MockRequest.new(Rails.application).get("/.well-known/cloudflare-tunnel?nonce=#{nonce}")
      expected = Cloudflare::Tunnel::Probe.signature(Cloudflare::Tunnel.configuration.probe_secret.call, nonce)
      if Rails.env.development?
        abort "Probe unavailable" unless response.status == 200 && response.body == expected
      else
        abort "Probe exposed outside development" if response.status == 200
      end
    RUBY
    %w[development production].each do |environment|
      output, error, status = Open3.capture3({"RAILS_ENV" => environment}, RbConfig.ruby, "-Ilib", "-e", script)
      assert status.success?, "#{environment}: #{output}\n#{error}"
    end
  end
end

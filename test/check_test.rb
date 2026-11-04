# frozen_string_literal: true

require "test_helper"
require "stringio"

class CheckTest < Minitest::Test
  def setup
    @config = Cloudflare::Tunnel::Configuration.new
    @config.hostname = "devel.example.test"
    @config.origin = "http://localhost:3000"
    @config.token = "private-token"
    @config.probe_secret = -> { "probe-secret" }
    @config.executable = RbConfig.ruby
    @output = StringIO.new
  end

  def stub_probe(url, secret: "probe-secret")
    stub_request(:get, %r{\A#{Regexp.escape(url)}#{Regexp.escape(Cloudflare::Tunnel::Probe::PATH)}\?nonce=}).to_return do |request|
      nonce = URI.decode_www_form(request.uri.query).to_h.fetch("nonce")
      {status: 200, body: Cloudflare::Tunnel::Probe.signature(secret, nonce)}
    end
  end

  def stub_healthy
    stub_probe(@config.origin)
    stub_probe("https://#{@config.hostname}")
    stub_request(:get, "http://127.0.0.1:20241/ready").to_return(status: 200)
  end

  def test_full_check_requires_local_connector_and_public_app_identity
    stub_healthy
    assert Cloudflare::Tunnel::Check.new(@config, output: @output).run
    assert_equal 3, @output.string.scan("OK:").size
    refute_includes @output.string, @config.token
  end

  def test_public_http_success_from_a_different_app_fails
    stub_healthy
    stub_probe("https://#{@config.hostname}", secret: "wrong-app")
    refute Cloudflare::Tunnel::Check.new(@config, output: @output).run
    assert_includes @output.string, "FAIL: public hostname"
  end

  def test_disconnected_connector_cannot_pass_with_a_healthy_origin
    stub_healthy
    stub_request(:get, "http://127.0.0.1:20241/ready").to_return(status: 503)
    refute Cloudflare::Tunnel::Check.new(@config, output: @output).run
    assert_includes @output.string, "FAIL: Cloudflare connection"
  end

  def test_offline_diagnostics_fail_cleanly_without_leaking_credentials
    stub_request(:get, /localhost|127\.0\.0\.1|devel\.example\.test/).to_timeout
    refute Cloudflare::Tunnel::Check.new(@config, output: @output).run
    assert_equal 3, @output.string.scan("FAIL:").size
    refute_includes @output.string, @config.token
  end

  def test_missing_binary_links_to_installation_without_making_requests
    @config.executable = "/missing/cloudflared"
    refute Cloudflare::Tunnel::Check.new(@config, output: @output).run
    assert_includes @output.string, Cloudflare::Tunnel::INSTALL_URL
    assert_not_requested :get, /.*/
  end
end

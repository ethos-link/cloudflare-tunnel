# frozen_string_literal: true

require "test_helper"
require "rack/mock"

class ProbeTest < Minitest::Test
  def setup
    app = Cloudflare::Tunnel::Probe.new(->(_env) { [404, {}, ["app"]] }, secret: -> { "app-specific-secret" })
    @request = Rack::MockRequest.new(app)
    @path = Cloudflare::Tunnel::Probe::PATH
  end

  def test_probe_is_signed_and_uncacheable
    nonce = "a" * 64
    response = @request.get("#{@path}?nonce=#{nonce}")
    assert_equal 200, response.status
    assert_equal Cloudflare::Tunnel::Probe.signature("app-specific-secret", nonce), response.body
    assert_equal "no-store", response["cache-control"]
    refute_includes response.body, "app-specific-secret"
  end

  def test_other_paths_pass_through_and_malformed_probes_fail
    assert_equal 404, @request.get("/up").status
    assert_equal 400, @request.get(@path).status
    assert_equal 400, @request.post("#{@path}?nonce=#{"a" * 64}").status
  end
end

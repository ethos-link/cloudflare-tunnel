# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @config = Cloudflare::Tunnel::Configuration.new
    @config.hostname = "devel.example.test"
  end

  def test_defaults_keep_connector_output_separate_and_quiet
    assert_empty @config.errors
    assert_equal :error, @config.log_level
    assert_equal "log/cloudflare-tunnel.log", @config.log_path
    assert_equal 30, @config.retry_interval
    assert_nil @config.token
  end

  def test_invalid_options_are_rejected
    @config.hostname = "https://example.test/path"
    @config.origin = "http://remote.test:3000"
    @config.log_level = :verbose
    @config.metrics_port = 0
    @config.retry_interval = 0
    @config.shutdown_timeout = Float::INFINITY
    assert_equal 6, @config.errors.size
  end

  def test_token_is_lazy_and_executable_can_be_explicit
    @config.token = -> { " test-token\n" }
    @config.executable = RbConfig.ruby
    assert_equal "test-token", @config.token_value
    assert_equal RbConfig.ruby, @config.executable_path
  end

  def test_disable_environment_switch
    previous = ENV["TUNNEL"]
    ENV["TUNNEL"] = "off"
    refute Cloudflare::Tunnel::Configuration.new.enabled
  ensure
    ENV["TUNNEL"] = previous
  end
end

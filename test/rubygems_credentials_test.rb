# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "json"

class RubygemsCredentialsTest < Minitest::Test
  def setup
    WebMock.reset!
    @environment_file = Tempfile.new("rubygems-environment")
    @variables = {
      "RUBYGEMS_OWNER" => "27209",
      "ACTIONS_ID_TOKEN_REQUEST_URL" => "https://token.actions.githubusercontent.com/token?existing=value",
      "ACTIONS_ID_TOKEN_REQUEST_TOKEN" => "github-request-token",
      "GITHUB_ENV" => @environment_file.path
    }
    @previous_environment = ENV.to_h.slice(*@variables.keys)
    ENV.update(@variables)
    @identity_request = stub_request(:get, "https://token.actions.githubusercontent.com/token")
      .with(query: {"existing" => "value", "audience" => "rubygems.org"}, headers: {"Authorization" => "Bearer github-request-token"})
      .to_return(body: JSON.generate(value: "oidc-jwt"))
    @exchange_request = stub_request(:post, "https://rubygems.org/api/v1/oidc/trusted_publisher/exchange_token")
      .with(body: {jwt: "oidc-jwt", owner: "27209"}.to_json, headers: {"Content-Type" => "application/json", "Accept" => "application/json"})
      .to_return(status: 201, body: JSON.generate(rubygems_api_key: "rubygems_test_key"))
  end

  def teardown
    @variables.each_key { |key| ENV.delete(key) }
    ENV.update(@previous_environment)
    @environment_file.close!
  end

  def test_exchanges_identity_with_owner_and_masks_credentials
    output, = capture_io { configure_credentials }
    assert_requested @identity_request
    assert_requested @exchange_request
    assert_equal "GEM_HOST_API_KEY=rubygems_test_key\n", File.read(@environment_file.path)
    assert_includes output, "::add-mask::oidc-jwt"
    assert_includes output, "::add-mask::rubygems_test_key"
  end

  def test_failed_exchange_does_not_export_credentials_or_print_response_body
    stub_request(:post, "https://rubygems.org/api/v1/oidc/trusted_publisher/exchange_token").to_return(status: 403, body: "sensitive response content")
    output, error = capture_io { assert_raises(SystemExit) { configure_credentials } }
    assert_includes error, "HTTP 403"
    refute_includes output + error, "sensitive response content"
    assert_empty File.read(@environment_file.path)
  end

  def test_empty_key_is_rejected
    stub_request(:post, "https://rubygems.org/api/v1/oidc/trusted_publisher/exchange_token").to_return(status: 201, body: JSON.generate(rubygems_api_key: ""))
    _, error = capture_io { assert_raises(SystemExit) { configure_credentials } }
    assert_includes error, "Missing RubyGems API key"
    assert_empty File.read(@environment_file.path)
  end

  def test_owner_must_be_a_numeric_id
    ENV["RUBYGEMS_OWNER"] = "ethos-link"
    _, error = capture_io { assert_raises(SystemExit) { configure_credentials } }
    assert_includes error, "numeric account ID"
    assert_not_requested @identity_request
    assert_not_requested @exchange_request
  end

  private

  def configure_credentials
    load File.expand_path("../bin/configure-rubygems-credentials", __dir__), true
  end
end

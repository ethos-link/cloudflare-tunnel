# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end
require "cloudflare/tunnel"

require "minitest/autorun"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

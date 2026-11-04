# frozen_string_literal: true

require_relative "tunnel/version"
require_relative "tunnel/configuration"
require_relative "tunnel/runner"
require_relative "tunnel/probe"
require_relative "tunnel/check"

module Cloudflare
  module Tunnel
    INSTALL_URL = "https://developers.cloudflare.com/tunnel/downloads/"

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield configuration
    end
  end
end

require_relative "tunnel/railtie" if defined?(Rails::Railtie)

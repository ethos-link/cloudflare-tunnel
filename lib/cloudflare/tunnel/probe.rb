# frozen_string_literal: true

require "openssl"
require "rack/request"

module Cloudflare
  module Tunnel
    class Probe
      PATH = "/.well-known/cloudflare-tunnel"

      def self.signature(secret, nonce)
        OpenSSL::HMAC.hexdigest("SHA256", secret, nonce)
      end

      def initialize(app, secret:)
        @app = app
        @secret = secret
      end

      def call(env)
        request = Rack::Request.new(env)
        return @app.call(env) unless request.path_info == PATH

        nonce = request.GET["nonce"].to_s
        if request.get? && nonce.match?(/\A[0-9a-f]{64}\z/)
          [200, {"content-type" => "text/plain", "cache-control" => "no-store"}, [self.class.signature(@secret.call, nonce)]]
        else
          [400, {"content-type" => "text/plain", "cache-control" => "no-store"}, ["Invalid probe"]]
        end
      end
    end
  end
end

# frozen_string_literal: true

require "net/http"
require "securerandom"

module Cloudflare
  module Tunnel
    class Check
      NETWORK_ERRORS = [SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError].freeze

      def initialize(configuration, output: $stdout)
        @configuration = configuration
        @output = output
      end

      def run
        issues = @configuration.errors
        issues << "tunnel is disabled" unless @configuration.enabled
        issues << "cloudflared not found. Install it yourself: #{INSTALL_URL}" unless @configuration.executable_path
        issues << "token missing; set cloudflare.tunnel.token in Rails credentials" if @configuration.token_value.empty?
        if issues.any?
          issues.each { |issue| @output.puts("FAIL: #{issue}") }
          return false
        end

        nonce = SecureRandom.hex(32)
        expected = Probe.signature(@configuration.probe_secret.call, nonce)
        local = verify("local origin", "#{@configuration.origin.to_s.chomp("/")}#{Probe::PATH}?nonce=#{nonce}", expected)
        connector = verify("Cloudflare connection", "http://127.0.0.1:#{@configuration.metrics_port}/ready")
        public_app = verify("public hostname", "https://#{@configuration.hostname}#{Probe::PATH}?nonce=#{nonce}", expected)
        @output.puts("Origin must be #{@configuration.origin} in Cloudflare's published application settings.") unless local && connector && public_app
        local && connector && public_app
      end

      private

      def verify(label, url, expected = nil)
        uri = URI(url)
        # Ignore proxy environment variables for loopback diagnostics.
        http = Net::HTTP.new(uri.hostname, uri.port, (uri.hostname == @configuration.hostname) ? :ENV : nil)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = http.read_timeout = http.write_timeout = @configuration.check_timeout
        http.max_retries = 0
        response = http.get(uri.request_uri, {"Cache-Control" => "no-cache"})
        if response.code == "200" && (!expected || response.body == expected)
          @output.puts("OK: #{label}")
          true
        else
          @output.puts("FAIL: #{label} (HTTP #{response.code}; expected #{expected ? "this Rails application" : "an active connector"}). Check DNS, Cloudflare Access, origin and #{@configuration.log_path || "logging configuration"}.")
          false
        end
      rescue *NETWORK_ERRORS => error
        @output.puts("FAIL: #{label} (#{error.class}); network or service unavailable")
        false
      end
    end
  end
end

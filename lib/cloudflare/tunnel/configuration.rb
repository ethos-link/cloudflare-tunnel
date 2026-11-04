# frozen_string_literal: true

require "uri"

module Cloudflare
  module Tunnel
    class Configuration
      LOG_LEVELS = %w[debug info warn error fatal].freeze
      attr_accessor :enabled, :executable, :token, :hostname, :origin, :metrics_port,
        :log_level, :log_path, :retry_interval, :shutdown_timeout, :check_timeout,
        :root, :probe_secret

      def initialize
        @enabled = !%w[0 false off no].include?(ENV.fetch("TUNNEL", "1").downcase)
        @executable = "cloudflared"
        @root = Dir.pwd
        @origin = "http://localhost:#{ENV.fetch("PORT", "3000")}"
        @metrics_port = 20241
        @log_level = :error
        @log_path = "log/cloudflare-tunnel.log"
        @retry_interval = 30
        @shutdown_timeout = 5
        @check_timeout = 5
      end

      def token_value
        (token.respond_to?(:call) ? token.call : token).to_s.strip
      end

      def executable_path
        paths = executable.to_s.include?(File::SEPARATOR) ? [File.expand_path(executable, root)] :
          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |directory| File.join(directory, executable) }
        paths.find { |path| File.file?(path) && File.executable?(path) }
      end

      def path(value)
        File.expand_path(value, root)
      end

      def errors
        messages = []
        messages << "hostname must be a bare public hostname" unless hostname.to_s.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i)
        uri = URI.parse(origin.to_s)
        unless uri.is_a?(URI::HTTP) && %w[localhost 127.0.0.1 ::1].include?(uri.hostname) &&
            uri.userinfo.nil? && [nil, "", "/"].include?(uri.path) && uri.query.nil? && uri.fragment.nil?
          messages << "origin must be an HTTP(S) loopback URL without a path or credentials"
        end
        messages << "metrics_port must be between 1 and 65535" unless metrics_port.is_a?(Integer) && (1..65535).cover?(metrics_port)
        messages << "log_level must be one of #{LOG_LEVELS.join(", ")}" unless LOG_LEVELS.include?(log_level.to_s)
        %i[retry_interval shutdown_timeout check_timeout].each do |name|
          value = case name
          when :retry_interval then retry_interval
          when :shutdown_timeout then shutdown_timeout
          when :check_timeout then check_timeout
          end
          messages << "#{name} must be a positive finite number" unless value.is_a?(Numeric) && value.finite? && value.positive?
        end
        messages
      rescue URI::InvalidURIError
        messages << "origin must be a valid loopback URL"
      end
    end
  end
end

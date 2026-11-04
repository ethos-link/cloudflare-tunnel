# frozen_string_literal: true

require "fileutils"
require "tempfile"

module Cloudflare
  module Tunnel
    class Runner
      def initialize(configuration, output: $stdout)
        @configuration = configuration
        @output = output
        @stopping = false
      end

      def run
        @reader, @writer = IO.pipe
        previous = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { stop }] }
        if (reason = unavailable)
          @output.puts("[tunnel] #{reason}")
          pause
        else
          FileUtils.mkdir_p(@configuration.path("tmp/pids"))
          File.open(@configuration.path("tmp/pids/cloudflare-tunnel.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
            if lock.flock(File::LOCK_EX | File::LOCK_NB)
              supervise
            else
              @output.puts("[tunnel] already running for this application; skipping")
              pause
            end
          end
        end
      ensure
        terminate
        previous&.each { |signal, handler| Signal.trap(signal, handler) }
        @reader&.close
        @writer&.close
      end

      private

      def unavailable
        if !@configuration.enabled
          "disabled"
        elsif !@configuration.executable_path
          "cloudflared not found. Install it yourself: #{INSTALL_URL}"
        elsif @configuration.errors.any?
          "invalid configuration: #{@configuration.errors.join("; ")}"
        elsif @configuration.token_value.empty?
          "token missing; set cloudflare.tunnel.token in Rails credentials"
        end
      end

      def supervise
        log_path = @configuration.log_path && @configuration.path(@configuration.log_path)
        FileUtils.mkdir_p(File.dirname(log_path)) if log_path
        File.open(log_path || File::NULL, "a", 0o600) do |log|
          Tempfile.create(["cloudflare-tunnel-", ".token"]) do |token|
            token.write(@configuration.token_value)
            token.flush
            @output.puts("[tunnel] #{@configuration.hostname} -> #{@configuration.origin}; diagnostics: #{log_path || "disabled"}")
            until @stopping
              @pid = Process.spawn({"TUNNEL_TOKEN" => nil, "TUNNEL_TOKEN_FILE" => nil,
                "TUNNEL_LOGFILE" => nil, "TUNNEL_LOGDIRECTORY" => nil},
                @configuration.executable_path, "tunnel", "--no-autoupdate",
                "--loglevel", @configuration.log_level.to_s,
                "--metrics", "127.0.0.1:#{@configuration.metrics_port}",
                "--grace-period", "2s", "run", "--token-file", token.path,
                out: log, err: log)
              @waiter = Process.detach(@pid)
              pause(1) until @stopping || @waiter.join(0)
              terminate
              pause(@configuration.retry_interval) unless @stopping
            end
          ensure
            terminate
          end
        end
      end

      def stop
        @stopping = true
        @writer.write_nonblock(".", exception: false)
      end

      def pause(timeout = nil)
        IO.select([@reader], nil, nil, timeout) unless @stopping
      end

      def terminate
        return unless @waiter

        unless @waiter.join(0)
          Process.kill("TERM", @pid)
          unless @waiter.join(@configuration.shutdown_timeout)
            Process.kill("KILL", @pid)
            @waiter.join
          end
        end
      rescue Errno::ESRCH
        @waiter.join
      ensure
        @waiter = @pid = nil
      end
    end
  end
end

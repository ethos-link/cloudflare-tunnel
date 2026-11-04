# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "socket"
require "timeout"
require "json"

class RunnerTest < Minitest::Test
  def with_runner(mode: "retry", executable: nil, enabled: true, token: "private-test-token", log_path: "log/tunnel.log")
    Dir.mktmpdir("cloudflare-tunnel-test") do |root|
      socket_path = File.join(root, "events.sock")
      server = UNIXServer.new(socket_path)
      binary = File.join(root, "cloudflared")
      File.write(binary, <<~RUBY)
        #!#{RbConfig.ruby}
        require "socket"
        require "json"
        token = ARGV.last
        trap("TERM") { exit 0 } unless ENV["MODE"] == "stubborn"
        trap("TERM", "IGNORE") if ENV["MODE"] == "stubborn"
        STDERR.puts "connector diagnostic"
        UNIXSocket.open(ENV.fetch("EVENT_SOCKET")) do |socket|
          socket.puts JSON.generate(pid: Process.pid, arguments: ARGV, token: File.read(token),
            permissions: File.stat(token).mode & 0777, environment_token: ENV["TUNNEL_TOKEN"])
        end
        if ENV["MODE"] == "retry" && !File.exist?("attempted")
          File.write("attempted", "yes")
          exit 1
        end
        exit 1 if ENV["MODE"] == "timer"
        sleep
      RUBY
      File.chmod(0o755, binary)
      script = <<~RUBY
        require "cloudflare/tunnel"
        config = Cloudflare::Tunnel::Configuration.new
        config.root = #{root.inspect}
        config.hostname = "devel.example.test"
        config.token = #{token.inspect}
        config.executable = #{(executable || binary).inspect}
        config.enabled = #{enabled.inspect}
        config.log_path = #{log_path.inspect}
        config.log_level = :warn
        config.retry_interval = #{(mode == "timer") ? 60 : 0.02}
        config.shutdown_timeout = 0.05
        $stdout.sync = true
        Cloudflare::Tunnel::Runner.new(config).run
      RUBY
      File.write(File.join(root, "runner.rb"), script)
      env = {"MODE" => mode, "EVENT_SOCKET" => socket_path, "TUNNEL" => "1", "TUNNEL_TOKEN" => "inherited-private-token", "TMPDIR" => root}
      Open3.popen3(env, RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", script, chdir: root) do |input, output, error, process|
        input.close
        begin
          Timeout.timeout(10) { yield root, server, output, error, process }
        ensure
          if process.alive?
            Process.kill("TERM", process.pid)
            Process.kill("KILL", process.pid) unless process.join(2)
          end
        end
      end
    ensure
      server&.close
    end
  end

  def event(server)
    socket = server.accept
    JSON.parse(socket.gets)
  ensure
    socket&.close
  end

  def test_failures_retry_silently_and_shutdown_cleans_child_and_token
    with_runner do |root, server, output, error, process|
      event(server)
      child = event(server)
      assert process.alive?
      assert_equal "private-test-token", child.fetch("token")
      assert_equal 0o600, child.fetch("permissions")
      assert_nil child.fetch("environment_token")
      assert_includes child.fetch("arguments"), "warn"
      refute_includes child.fetch("arguments"), "private-test-token"
      Process.kill("TERM", process.pid)
      assert process.value.success?
      assert_raises(Errno::ESRCH) { Process.kill(0, child.fetch("pid")) }
      refute File.exist?(child.fetch("arguments").last)
      assert_empty Dir[File.join(root, "cloudflare-tunnel-*.token")]
      refute_includes output.read + error.read, "connector diagnostic"
      assert_includes File.read(File.join(root, "log/tunnel.log")), "connector diagnostic"
    end
  end

  def test_shutdown_interrupts_retry_delay
    with_runner(mode: "timer") do |root, server, _output, _error, process|
      event(server)
      Process.kill("TERM", process.pid)
      assert process.join(2), "Shutdown waited for the retry interval"
      assert process.value.success?
      assert_empty Dir[File.join(root, "cloudflare-tunnel-*.token")]
    end
  end

  def test_shutdown_kills_a_connector_that_ignores_term
    with_runner(mode: "stubborn", log_path: nil) do |_root, server, _output, _error, process|
      child = event(server)
      Process.kill("TERM", process.pid)
      assert process.join(2), "Stubborn connector blocked shutdown"
      assert_raises(Errno::ESRCH) { Process.kill(0, child.fetch("pid")) }
    end
  end

  def test_missing_binary_provides_install_link_and_keeps_foreman_process_alive
    with_runner(executable: "/missing/cloudflared") do |root, _server, output, error, process|
      assert_includes output.gets, Cloudflare::Tunnel::INSTALL_URL
      assert process.alive?
      refute File.exist?(File.join(root, "attempted"))
      Process.kill("TERM", process.pid)
      assert process.value.success?
      assert_empty error.read
    end
  end

  def test_disabled_tunnel_is_idle_without_creating_a_token
    with_runner(enabled: false) do |root, _server, output, _error, process|
      assert_includes output.gets, "disabled"
      assert_empty Dir[File.join(root, "cloudflare-tunnel-*.token")]
      assert process.alive?
      Process.kill("TERM", process.pid)
      assert process.value.success?
    end
  end

  def test_missing_token_stays_idle_without_starting_a_connector
    with_runner(token: nil) do |root, _server, output, _error, process|
      assert_includes output.gets, "token missing"
      refute File.exist?(File.join(root, "attempted"))
      assert process.alive?
      Process.kill("TERM", process.pid)
      assert process.value.success?
    end
  end

  def test_second_supervisor_stays_idle_without_disturbing_the_first
    with_runner(mode: "running") do |root, server, _output, _error, process|
      child = event(server)
      Open3.popen3(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), File.join(root, "runner.rb"), chdir: root) do |input, output, error, duplicate|
        input.close
        begin
          assert_includes output.gets, "already running"
          assert duplicate.alive?
          Process.kill("TERM", duplicate.pid)
          assert duplicate.value.success?
          assert_empty error.read
        ensure
          Process.kill("KILL", duplicate.pid) if duplicate.alive?
        end
      end
      assert process.alive?
      assert Process.kill(0, child.fetch("pid"))
      Process.kill("TERM", process.pid)
      assert process.value.success?
    end
  end
end

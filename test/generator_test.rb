# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/cloudflare_tunnel/install_generator"
require "tmpdir"

class GeneratorTest < Rails::Generators::TestCase
  tests Cloudflare::Tunnel::Generators::InstallGenerator

  def setup
    @directory = Dir.mktmpdir("cloudflare-tunnel-generator")
    self.destination_root = @directory
    File.write(File.join(@directory, "Procfile.dev"), "web: bin/rails server\njobs: bin/jobs\ntunnel: bin/tunnel\n")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_installer_configures_rails_and_migrates_the_legacy_procfile_entry
    arguments = ["--hostname=devel.example.test", "--port=3100", "--metrics-port=20242"]
    run_generator(arguments)
    assert_file "config/initializers/cloudflare_tunnel.rb", /config.hostname = "devel.example.test"/
    assert_file "config/initializers/cloudflare_tunnel.rb", /config.metrics_port = 20242/
    assert_file "config/initializers/cloudflare_tunnel.rb", /config.log_level = :error/
    assert_file "Procfile.dev", "web: bin/rails server\njobs: bin/jobs\ntunnel: bin/rails cloudflare_tunnel:start\n"
    run_generator(arguments)
    assert_equal 1, File.read(File.join(@directory, "Procfile.dev")).scan(/^tunnel:/).size
  end

  def test_installer_preserves_custom_tunnel_commands
    File.write(File.join(@directory, "Procfile.dev"), "tunnel: custom-command\n")
    run_generator(["--hostname=devel.example.test"])
    assert_file "Procfile.dev", "tunnel: custom-command\n"
  end
end

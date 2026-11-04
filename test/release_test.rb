# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"

class ReleaseTest < Minitest::Test
  def test_release_requires_tag_workflow_instead_of_local_publication
    output, error, status = Open3.capture3("bundle", "exec", "rake", "release")
    refute status.success?
    assert_includes output + error, "GitHub Actions publishes"
  end

  def test_release_verification_accepts_matching_version_and_rejects_mismatched_tag
    output, error, status = Open3.capture3({"RELEASE_TAG" => "v#{Cloudflare::Tunnel::VERSION}"}, "bundle", "exec", "rake", "release:verify")
    assert status.success?, output + error
    output, error, status = Open3.capture3({"RELEASE_TAG" => "v99.0.0"}, "bundle", "exec", "rake", "release:verify")
    refute status.success?
    assert_includes output + error, "Tag and gem version differ"
  end
end

class ReleasePrepareTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("tunnel-release-")
    @repo = File.join(@directory, "repo")
    @origin = File.join(@directory, "origin.git")
    FileUtils.mkdir_p([File.join(@repo, "tasks"), File.join(@repo, "lib/cloudflare/tunnel"), File.join(@repo, "bin")])
    FileUtils.cp(File.expand_path("../tasks/release.rake", __dir__), File.join(@repo, "tasks/release.rake"))
    FileUtils.cp(File.expand_path("../lib/cloudflare/tunnel/version.rb", __dir__), File.join(@repo, "lib/cloudflare/tunnel/version.rb"))
    File.write(File.join(@repo, "CHANGELOG.md"), "## [#{Cloudflare::Tunnel::VERSION}]\n")
    File.write(File.join(@repo, "Rakefile"), <<~RUBY)
      require "rake"
      %w[release release:source_control_push release:rubygem_push].each { |name| task name }
      load "tasks/release.rake"
    RUBY
    File.write(File.join(@repo, "bin/ci"), "#!/bin/sh\nexit 0\n")
    File.write(File.join(@repo, "bin/git-cliff"), <<~RUBY)
      #!#{RbConfig.ruby}
      version = ARGV.fetch(ARGV.index("--tag") + 1).delete_prefix("v")
      File.write("CHANGELOG.md", "## [\#{version}]\\n" + File.read("CHANGELOG.md"))
    RUBY
    FileUtils.chmod(0o755, [File.join(@repo, "bin/ci"), File.join(@repo, "bin/git-cliff")])
    git("init", "--bare", @origin)
    git("init", "-b", "main")
    git("config", "user.name", "Release Test")
    git("config", "user.email", "release@example.test")
    git("config", "core.hooksPath", File::NULL)
    git("add", ".")
    git("commit", "-m", "feat: initial version")
    git("remote", "add", "origin", @origin)
    git("push", "origin", "main")
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  def test_prepare_bumps_commits_and_pushes_branch_and_annotated_tag_from_main
    output, status = prepare("patch")
    assert status.success?, output
    major, minor, patch = Cloudflare::Tunnel::VERSION.split(".").map(&:to_i)
    version = "#{major}.#{minor}.#{patch + 1}"
    assert_includes File.read(File.join(@repo, "lib/cloudflare/tunnel/version.rb")), %(VERSION = "#{version}")
    assert_equal "chore(release): prepare v#{version}", git("log", "-1", "--format=%s").strip
    assert_equal "tag", git("cat-file", "-t", "v#{version}").strip
    assert_equal git("rev-parse", "HEAD"), git("--git-dir", @origin, "rev-parse", "main")
    assert_equal git("rev-parse", "HEAD"), git("--git-dir", @origin, "rev-parse", "v#{version}^{}")
    assert_empty git("status", "--porcelain")
  end

  def test_prepare_releases_current_version_when_no_release_tags_exist
    original_head = git("rev-parse", "HEAD")
    output, status = prepare(Cloudflare::Tunnel::VERSION)
    assert status.success?, output
    assert_equal original_head, git("rev-parse", "HEAD")
    assert_equal original_head, git("--git-dir", @origin, "rev-parse", "v#{Cloudflare::Tunnel::VERSION}^{}")
  end

  def test_prepare_rejects_feature_branch
    git("switch", "-c", "feature/example")
    output, status = prepare("patch")
    refute status.success?
    assert_includes output, "Release must run on main or master"
  end

  def test_prepare_rejects_untracked_files
    File.write(File.join(@repo, "untracked"), "unfinished")
    output, status = prepare("patch")
    refute status.success?
    assert_includes output, "clean working tree"
  end

  def test_prepare_rejects_existing_remote_tag_before_changing_files
    git("tag", "v99.0.0")
    git("push", "origin", "v99.0.0")
    git("tag", "-d", "v99.0.0")
    output, status = prepare("99.0.0")
    refute status.success?
    assert_includes output, "already exists on origin"
    assert_empty git("status", "--porcelain")
  end

  def test_prepare_rejects_current_version_after_a_release
    git("tag", "v#{Cloudflare::Tunnel::VERSION}")
    output, status = prepare(Cloudflare::Tunnel::VERSION)
    refute status.success?
    assert_includes output, "must be newer"
  end

  def test_prepare_requires_changelog_for_initial_release
    File.write(File.join(@repo, "CHANGELOG.md"), "No releases yet\n")
    git("add", "CHANGELOG.md")
    git("commit", "-m", "docs: remove release entry")
    output, status = prepare(Cloudflare::Tunnel::VERSION)
    refute status.success?
    assert_includes output, "Missing changelog entry"
    assert_empty git("tag", "--list")
  end

  def test_prepare_rejects_existing_local_tag_before_changing_files
    git("tag", "v99.0.0")
    output, status = prepare("99.0.0")
    refute status.success?
    assert_includes output, "already exists locally"
    assert_empty git("status", "--porcelain")
  end

  def test_failed_checks_prevent_commit_tag_and_push
    File.write(File.join(@repo, "bin/ci"), "#!/bin/sh\nexit 1\n")
    git("add", "bin/ci")
    git("commit", "-m", "test: simulate failed checks")
    original_head = git("rev-parse", "HEAD")
    remote_head = git("--git-dir", @origin, "rev-parse", "main")
    output, status = prepare("patch")
    refute status.success?, output
    assert_equal original_head, git("rev-parse", "HEAD")
    assert_equal remote_head, git("--git-dir", @origin, "rev-parse", "main")
    assert_empty git("tag", "--list")
  end

  private

  def prepare(target)
    Open3.capture2e({"PATH" => "#{@repo}/bin:#{ENV.fetch("PATH")}"}, RbConfig.ruby, "-S", "rake", "release:prepare[#{target}]", chdir: @repo)
  end

  def git(*arguments)
    output, status = Open3.capture2e("git", *arguments, chdir: @repo)
    raise output unless status.success?
    output
  end
end

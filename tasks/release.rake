# frozen_string_literal: true

require_relative "../lib/cloudflare/tunnel/version"

VERSION_PATH = File.expand_path("../lib/cloudflare/tunnel/version.rb", __dir__)
VALID_RELEASE_TARGETS = %w[major minor patch].freeze

def current_branch
  `git branch --show-current`.strip
end

def clean_worktree?
  `git status --porcelain`.empty?
end

def release_tag(version)
  "v#{version}"
end

def release_version(target)
  target = target.to_s.strip
  if target.empty?
    message = "Provide patch, minor, major, or an explicit X.Y.Z version."
    raise ArgumentError, message
  end

  return target if target.match?(/\A\d+\.\d+\.\d+\z/)

  unless VALID_RELEASE_TARGETS.include?(target)
    message = "Invalid release target #{target.inspect}. Use " \
      "#{VALID_RELEASE_TARGETS.join(", ")} or X.Y.Z."
    raise ArgumentError, message
  end

  major, minor, patch = Cloudflare::Tunnel::VERSION.split(".").map(&:to_i)

  case target
  when "major"
    "#{major + 1}.0.0"
  when "minor"
    "#{major}.#{minor + 1}.0"
  when "patch"
    "#{major}.#{minor}.#{patch + 1}"
  end
end

def validate_release_version!(version, current)
  initial_release = version == current && `git tag --list "v*"`.strip.empty?
  if Gem::Version.new(version) <= Gem::Version.new(current) && !initial_release
    message = "Release version #{version} must be newer than " \
      "current version #{current}."
    raise ArgumentError, message
  end

  tag = release_tag(version)
  if local_release_tag_exists?(tag)
    raise ArgumentError, "Release tag #{tag} already exists locally."
  end
  if remote_release_tag_exists?(tag)
    raise ArgumentError, "Release tag #{tag} already exists on origin."
  end
end

def local_release_tag_exists?(tag)
  system(
    "git",
    "rev-parse",
    "--quiet",
    "--verify",
    "refs/tags/#{tag}",
    out: File::NULL
  )
end

def remote_release_tag_exists?(tag)
  output = `#{remote_release_tag_command(tag)} 2>&1`
  status = $?

  if status.success?
    true
  elsif status.exitstatus == 2
    false
  else
    raise "Could not check origin for #{tag}: #{output.strip}"
  end
end

def remote_release_tag_command(tag)
  "git ls-remote --exit-code --tags origin refs/tags/#{tag}"
end

def update_version_file(version)
  File.write(
    VERSION_PATH,
    File.read(VERSION_PATH).sub(/VERSION = "[^"]+"/, "VERSION = #{version.inspect}")
  )
end

def changelog_command(version)
  [
    "git-cliff",
    "-c",
    "cliff.toml",
    "--unreleased",
    "--tag",
    release_tag(version),
    "--prepend",
    "CHANGELOG.md"
  ]
end

def update_changelog(version)
  success = system(*changelog_command(version))
  unless success
    message = "git-cliff failed. Install git-cliff and make sure " \
      "cliff.toml is valid."
    raise message
  end

  if system("git", "diff", "--quiet", "--", "CHANGELOG.md")
    message = "git-cliff did not update CHANGELOG.md. Ensure there are " \
      "Conventional Commits since the last tag."
    raise message
  end
end

# Publishing belongs exclusively to the tag-triggered GitHub workflow.
%w[release release:source_control_push release:rubygem_push].each do |name|
  Rake::Task[name].clear
  task name do
    abort "Use release:prepare[patch|minor|major|X.Y.Z]. GitHub Actions publishes."
  end
end
Rake::Task[:release].clear
desc "Explain the GitHub Actions release workflow"
task :release do
  abort "Use release:prepare[patch|minor|major|X.Y.Z] on main. GitHub Actions publishes."
end

namespace :release do
  desc "Prepare a release: update changelog/version, commit, tag, and push."
  task :prepare, [:target] do |_task, args|
    branch = current_branch
    unless %w[main master].include?(branch)
      message = "Release must run on main or master. Current branch: " \
        "#{branch.inspect}."
      abort message
    end
    abort "Release requires a clean working tree." unless clean_worktree?

    version = release_version(args[:target])
    current = Cloudflare::Tunnel::VERSION
    validate_release_version!(version, current)

    if version == current
      abort "Missing changelog entry for #{version}" unless File.read("CHANGELOG.md").match?(/^## \[#{Regexp.escape(version)}\]/)
    else
      update_changelog(version)
      update_version_file(version)
    end

    sh "bin/ci"
    tag = release_tag(version)

    unless clean_worktree?
      sh "git add CHANGELOG.md lib/cloudflare/tunnel/version.rb"
      sh %(LEFTHOOK=0 git commit -m "chore(release): prepare v#{version}")
    end
    sh %(git tag -a #{tag} -m "Release #{tag}")
    sh "git push origin #{branch}"
    sh "git push origin #{tag}"
  rescue ArgumentError, RuntimeError => e
    abort e.message
  end

  desc "Validate the current release's version, tag and changelog without publishing"
  task :verify do
    version = Cloudflare::Tunnel::VERSION
    tag = ENV.fetch("RELEASE_TAG", "v#{version}")
    abort "Tag and gem version differ" unless tag == "v#{version}"
    abort "Missing changelog entry for #{version}" unless File.read("CHANGELOG.md").match?(/^## \[#{Regexp.escape(version)}\]/)
    puts "Verified #{tag}"
  end

  desc "Run local checks and push the current version tag; GitHub Actions publishes"
  task tag: :verify do
    abort "Tag releases from main" unless `git branch --show-current`.strip == "main"
    abort "Release requires a clean working tree" unless `git status --porcelain`.empty?
    sh "git", "fetch", "origin", "main", "--tags"
    abort "main must match origin/main" unless `git rev-parse HEAD` == `git rev-parse origin/main`
    tag = "v#{Cloudflare::Tunnel::VERSION}"
    abort "Tag already exists" if system("git", "rev-parse", "--verify", "--quiet", "refs/tags/#{tag}", out: File::NULL)
    sh "bin/ci"
    sh "git", "tag", "-a", tag, "-m", "Release #{tag}"
    sh "git", "push", "origin", tag
  end
end

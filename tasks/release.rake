# frozen_string_literal: true

require "open3"
require_relative "../lib/cloudflare/tunnel/version"

# Publishing belongs exclusively to the tag-triggered GitHub workflow.
%w[release release:source_control_push release:rubygem_push].each do |name|
  Rake::Task[name].clear
  task name do
    abort "Use release:prepare and release:tag. GitHub Actions publishes."
  end
end
Rake::Task[:release].clear
desc "Explain the GitHub Actions release workflow"
task :release do
  abort "Use release:prepare[patch|minor|major|X.Y.Z] on a feature branch, merge, then release:tag on main. GitHub Actions publishes."
end

namespace :release do
  desc "Update version/changelog on a feature branch for review"
  task :prepare, [:target] do |_task, args|
    branch, status = Open3.capture2("git", "branch", "--show-current")
    abort "Cannot determine branch" unless status.success?
    abort "Use a feature branch for release preparation" if ["main", "master", ""].include?(branch.strip)
    abort "Release requires a clean working tree" unless `git status --porcelain`.empty?
    current = Cloudflare::Tunnel::VERSION
    segments = current.split(".").map(&:to_i)
    target = args[:target].to_s
    version = case target
    when "patch" then "#{segments[0]}.#{segments[1]}.#{segments[2] + 1}"
    when "minor" then "#{segments[0]}.#{segments[1] + 1}.0"
    when "major" then "#{segments[0] + 1}.0.0"
    else target
    end
    abort "Use patch, minor, major or a newer X.Y.Z" unless version.match?(/\A\d+\.\d+\.\d+\z/) && Gem::Version.new(version) > Gem::Version.new(current)
    sh "git-cliff", "--config", "cliff.toml", "--unreleased", "--tag", "v#{version}", "--prepend", "CHANGELOG.md"
    path = "lib/cloudflare/tunnel/version.rb"
    File.write(path, File.read(path).sub(/VERSION = "[^"]+"/, "VERSION = #{version.inspect}"))
    puts "Prepared #{version}. Review, run bin/ci, commit and open a PR. After merging, run release:tag on main."
  end

  desc "Validate the current release's version, tag and changelog without publishing"
  task :verify do
    version = Cloudflare::Tunnel::VERSION
    tag = ENV.fetch("RELEASE_TAG", "v#{version}")
    abort "Tag and gem version differ" unless tag == "v#{version}"
    abort "Missing changelog entry for #{version}" unless File.read("CHANGELOG.md").match?(/^## \[#{Regexp.escape(version)}\]/)
    puts "Verified #{tag}"
  end

  desc "Run local checks and push the merged version tag; GitHub Actions publishes"
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

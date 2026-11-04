# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest", "~> 5.0"
gem "simplecov", "~> 0.22", require: false
gem "webmock", "~> 3.0"

gem "ethos-gemkit", "~> 0.1", group: [:development, :test], require: false,
  git: "https://github.com/ethos-link/ethos-gemkit.git", ref: "e00a2ad179a9e53abf08a7ac696f42792d3c871b"

group :test do
  gem "railties", ">= 8.1", "< 9", require: false
end

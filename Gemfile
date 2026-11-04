# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest", "~> 5.0"
gem "simplecov", "~> 0.22", require: false
gem "webmock", "~> 3.0"

gem "ethos-gemkit", "~> 0.1", group: [:development, :test], require: false,
  git: "https://github.com/ethos-link/ethos-gemkit.git", ref: "8441b78f7c9bae4ce170485fb246d3775c43c748"

group :test do
  gem "railties", ">= 8.1", "< 9", require: false
end

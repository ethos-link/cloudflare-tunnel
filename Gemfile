# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest", "~> 5.0"
gem "simplecov", "~> 0.22", require: false
gem "webmock", "~> 3.0"

gem "ethos-gemkit", "~> 0.1", group: [:development, :test], require: false,
  git: "https://github.com/ethos-link/ethos-gemkit.git", ref: "2ec3e3279ce09e5a7dd2b84f050d86f6f8817ef7"

group :test do
  gem "railties", ">= 8.1", "< 9", require: false
end

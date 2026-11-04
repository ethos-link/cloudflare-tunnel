# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest", "~> 5.0"
gem "simplecov", "~> 0.22", require: false
gem "webmock", "~> 3.0"

# Pin development tooling and workflow callers together; override only for local work.
gemkit_source = ENV["ETHOS_GEMKIT_PATH"] ? {path: ENV.fetch("ETHOS_GEMKIT_PATH")} : {git: "https://github.com/ethos-link/ethos-gemkit.git", ref: "0780a40d5305c5df0c5c786f665e7ac2d4c673b9"}
group :development, :test do
  gem "ethos-gemkit", "~> 0.1", require: false, **gemkit_source
end

group :test do
  gem "railties", ">= 8.1", "< 9", require: false
end

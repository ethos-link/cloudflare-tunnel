# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest", "~> 5.0"
gem "simplecov", "~> 0.22", require: false
gem "webmock", "~> 3.0"

# Pin development tooling and workflow callers together; override only for local work.
gemkit_source = ENV["ETHOS_GEMKIT_PATH"] ? {path: ENV.fetch("ETHOS_GEMKIT_PATH")} : {git: "https://github.com/ethos-link/ethos-gemkit.git", ref: "02e6d96cd2110442b61468bdfbe99c5cc9c2fa2f"}
group :development, :test do
  gem "ethos-gemkit", "~> 0.1", require: false, **gemkit_source
end

group :test do
  gem "railties", ">= 8.1", "< 9", require: false
end

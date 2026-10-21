source "https://rubygems.org"

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails", github: "hotwired/turbo-rails", branch: "offline-cache"

# Deployment and drivers
gem "bootsnap", require: false
gem "kamal", require: false
gem "puma", "~> 8.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.5"
gem "sqlite3", ">= 2.9.6"
gem "thruster", require: false
gem "tzinfo-data" # the image's own zones lack the older names a browser may report

# Features
gem "bcrypt", "~> 3.1.22"
gem "geared_pagination", "~> 1.2"
gem "rails-active_search", "~> 0.1.0"
gem "rqrcode"
gem "jbuilder"
gem "lexxy", "1.0.1"
gem "image_processing", "~> 2.1"
gem "ruby-vips", "~> 2.3", require: false
gem "platform_agent"
gem "aws-sdk-s3", require: false
gem "useragent", github: "basecamp/useragent"
gem "surfguard", github: "basecamp/surfguard"
gem "filter_path_parameters", github: "mailpiece/filter_path_parameters", branch: "main"

# Operations
gem "mission_control-jobs"

gem "benchmark" # indirect dependency, being removed from Ruby 3.5 stdlib so here to quash warnings

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug"
  gem "letter_opener"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "minitest-reporters", require: false
  gem "mocha"
  gem "selenium-webdriver"
  gem "webmock"
end

gem "base64" # required on Ruby >= 3.4, dropped from default gems

# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_downloadable.gemspec
gemspec

# Private Recording Studio gems are not published to RubyGems.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.196"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.10.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.6.1"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end

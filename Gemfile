# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_downloadable.gemspec
gemspec

# Private Recording Studio gems are not published to RubyGems.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.6.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.17.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"
# Required by attachable >= 0.14 (not on RubyGems)
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.2.0"
# Required by accessible >= 0.17 (query-only; not on RubyGems)
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.10.0", require: false

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

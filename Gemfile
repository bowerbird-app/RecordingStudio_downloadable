# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_downloadable.gemspec
gemspec

# Private Recording Studio gems are not published to RubyGems.
# flatpack v0.1.356. view_component stays on Flatpack's ">= 4.14", "< 5".
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.356"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.10.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.32.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.23.0"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.4"
# Required by attachable >= 0.14 (not on RubyGems)
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"
# Required by accessible >= 0.17 (query-only; not on RubyGems)
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.0", require: false
# Attachable 0.23 requires Recording Studio API ~> 0.23 (git-only, with Moveable and Icons).
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.23.0", require: false
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1", require: false
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.1", require: false
gem "redis", "~> 5.3", require: false

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

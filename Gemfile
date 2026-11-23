# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_downloadable.gemspec
gemspec

# Private Recording Studio gems are not published to RubyGems.
# flatpack v0.2.0. view_component stays on Flatpack's ">= 4.14", "< 5".
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.9", github: "bowerbird-app/RecordingStudio", tag: "v7.9.1"
gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
gem "recording_studio_attachable", "~> 0.34", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.0"
gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
# Required by attachable >= 0.14 (not on RubyGems)
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
# Required by accessible >= 0.17 (query-only; not on RubyGems)
gem "recording_studio_trashable", "~> 1.3",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0", require: false
# Attachable 0.34 requires Recording Studio API >= 1.1 (git-only, with Moveable and Icons).
gem "recording_studio_api", "~> 1.21",
    github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.3", require: false
# Optional at runtime. Named tools need Recording Studio MCP >= 0.45, < 0.46.
# MCP needs Admin, Oauth, and Site Settings. None of these are required to boot the gem.
gem "recording_studio_admin", "~> 2.20",
    github: "bowerbird-app/RecordingStudio_admin", tag: "v2.20.0", require: false
gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0", require: false
gem "recording_studio_mcp", ">= 0.45", "< 0.46",
    github: "bowerbird-app/RecordingStudio_MCP", tag: "v0.45.2", require: false
gem "recording_studio_moveable", "~> 6.1",
    github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0", require: false
gem "recording_studio_oauth", "~> 0.26",
    github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.26.0", require: false
gem "recording_studio_site_settings", "~> 0.7",
    github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.7.0", require: false
gem "redis", "~> 5.3", require: false

gem "devise"
gem "puma", "8.1.2"
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

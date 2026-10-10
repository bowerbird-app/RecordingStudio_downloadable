# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]

  download_audience = {
    allowed: %i[granted],
    default: :granted,
    granted_roles: %i[view edit admin],
    granted_override: true,
    manage_role: :admin
  }

  config.action_audiences[:"workspaces.download"] = download_audience
  config.action_audiences[:"press_kits.download"] = download_audience
  config.action_audiences[:"pages.download"] = download_audience
end

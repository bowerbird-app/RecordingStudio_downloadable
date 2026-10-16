# frozen_string_literal: true

RecordingStudioDownloadable.configure do |config|
  config.auth_roles = { download: :view }
end

Rails.application.config.to_prepare do
  RecordingStudioDownloadable.configuration.register_access_denied_component(
    :"workspaces.download",
    DownloadAccessComponent
  )
  RecordingStudioDownloadable.configuration.register_download_gate(
    :"workspaces.download",
    WorkspaceDownloadGate
  )
end

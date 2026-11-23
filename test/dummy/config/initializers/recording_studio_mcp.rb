# frozen_string_literal: true

return unless defined?(RecordingStudioMcp)

RecordingStudioMcp.configure do |config|
  config.mcp_mount_path = "/recording_studio_mcp"
  config.oauth_protected_resource_path = "/.well-known/oauth-protected-resource/recording_studio_mcp"
  config.oauth_engine_mount_path = "/recording_studio_oauth"
end

RecordingStudioMcp.register_type(
  type: "Workspace",
  description: "A workspace whose files can be packaged into a ZIP."
)
RecordingStudioMcp.register_type(
  type: "Page",
  description: "A page in a workspace."
)
RecordingStudioMcp.register_type(
  type: "PressKit",
  description: "A press kit."
)

Rails.application.config.to_prepare do
  RecordingStudioMcp.register_server(:public, api: :public) do
    include_tools(:list, :show, *RecordingStudioDownloadable::McpCopy.tool_names)
  end
end

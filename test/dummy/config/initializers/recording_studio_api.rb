# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Downloadable API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
end

RecordingStudioApi.register_recordable_type_api(
  "Workspace",
  operations: %i[index show],
  capability_actions: %i[downloadable_download downloadable_package_status],
  serializer: ->(workspace, **) { { name: workspace.name } },
  output_keys: %i[name]
)

# Page and Press kit opted into Downloadable. The named tools need them on the API.
# Folder did not opt in, so it stays off this list.
RecordingStudioApi.register_recordable_type_api(
  "Page",
  operations: [],
  capability_actions: %i[downloadable_download downloadable_package_status],
  serializer: ->(page, **) { { title: page.title } },
  output_keys: %i[title]
)
RecordingStudioApi.register_recordable_type_api(
  "PressKit",
  operations: [],
  capability_actions: %i[downloadable_download downloadable_package_status],
  serializer: ->(press_kit, **) { { name: press_kit.name } },
  output_keys: %i[name]
)

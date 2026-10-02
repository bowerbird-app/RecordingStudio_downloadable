# frozen_string_literal: true

RecordingStudioDownloadable.configure do |config|
  # Maps Downloadable actions to RecordingStudio Accessible roles. V1 only uses
  # :download. Accessible is not modified by this gem; it receives a role.
  # config.auth_roles = { download: :view }

  # Optional override. Must respond to call(action:, actor:, recording:, role:).
  # When unset, Downloadable calls RecordingStudioAccessible::Authorization.allowed?
  # config.authorize_with = nil
end

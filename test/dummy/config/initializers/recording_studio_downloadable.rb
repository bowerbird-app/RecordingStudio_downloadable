# frozen_string_literal: true

RecordingStudioDownloadable.configure do |config|
  config.auth_roles = { download: :view }
end

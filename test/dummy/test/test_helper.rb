# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module RecordingStudioDownloadableDummyAccess
  # Seeds already bootstrap admin@admin.com on Studio Workspace. A second
  # bootstrap does not grant anyone else, so home-page examples that need the
  # download button must invite themselves through that owner.
  def grant_studio_download_access!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return if result.success?

    manager = User.find_by(email: "admin@admin.com")
    raise result.error if manager.nil?

    granted = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :admin,
      manager_actor: manager
    )
    raise granted.error if granted.failure?
  end
end

class ActionDispatch::IntegrationTest
  include RecordingStudioDownloadableDummyAccess
end

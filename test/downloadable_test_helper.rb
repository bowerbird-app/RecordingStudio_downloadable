# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"
require "devise/test/integration_helpers"
require "rails/test_help"
require "stringio"
require "zip"

module DownloadableTestHelper
  def create_workspace_recording(name: "Download Workspace #{SecureRandom.hex(4)}")
    workspace = Workspace.create!(name: name)
    RecordingStudio.root_recording_for(workspace)
  end

  def grant_download_access!(recording, actor)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
  end

  def attach_file!(parent_recording, filename:, contents:, content_type: "text/plain", actor:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(contents),
      filename: filename,
      content_type: content_type
    )
    attachment = RecordingStudioAttachable::Attachment.build_from_blob(
      blob: blob,
      root_recording: parent_recording.root_recording || parent_recording
    )
    attachment.save!
    RecordingStudio.record!(
      action: "attachment_uploaded",
      recordable: attachment,
      root_recording: parent_recording.root_recording || parent_recording,
      parent_recording: parent_recording,
      actor: actor
    ).recording
  end
end

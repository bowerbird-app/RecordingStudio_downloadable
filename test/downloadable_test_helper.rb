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

  def attach_file!(parent_recording, filename:, contents:, actor:, content_type: "text/plain")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(contents),
      filename: filename,
      content_type: content_type
    )
    parent_recording.record_attachment_upload(
      signed_blob_id: blob.signed_id,
      actor: actor,
      name: File.basename(filename, ".*").presence || filename
    )
  end
end

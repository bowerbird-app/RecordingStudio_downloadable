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

  def create_blob!(filename:, contents:, content_type: "text/plain")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(contents),
      filename: filename,
      content_type: content_type
    )
  end

  def with_downloadable_options(recordable_class, **options)
    previous = RecordingStudio.capability_options(:downloadable, for: recordable_class)
    RecordingStudio.set_capability_options(:downloadable, on: recordable_class, **options)
    yield
  ensure
    restore = previous || { source: :attachments, format: :zip }
    RecordingStudio.set_capability_options(:downloadable, on: recordable_class, **restore)
  end

  def install_workspace_manifest!(*files)
    Thread.current[:recording_studio_downloadable_manifest] = files
    return if Workspace.method_defined?(:downloadable_manifest)

    Workspace.define_method(:downloadable_manifest) do
      Thread.current[:recording_studio_downloadable_manifest]
    end
  end

  def uninstall_workspace_manifest!
    Thread.current[:recording_studio_downloadable_manifest] = nil
    Workspace.remove_method(:downloadable_manifest) if Workspace.method_defined?(:downloadable_manifest)
  end

  def zip_entries_from(io_or_string)
    payload = io_or_string.respond_to?(:read) ? io_or_string.tap(&:rewind).read : io_or_string
    entries = {}
    Zip::File.open_buffer(payload) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    entries
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

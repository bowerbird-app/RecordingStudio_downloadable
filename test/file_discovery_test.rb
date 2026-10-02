# frozen_string_literal: true

require_relative "downloadable_test_helper"

class FileDiscoveryTest < ActiveSupport::TestCase
  include DownloadableTestHelper

  setup do
    @actor = User.create!(email: "discovery-#{SecureRandom.hex(4)}@example.com", password: "Password", password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
  end

  test "collects direct attachments of arbitrary types" do
    attach_file!(@recording, filename: "notes.txt", contents: "txt", content_type: "text/plain", actor: @actor)
    attach_file!(@recording, filename: "doc.docx", contents: "docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", actor: @actor)
    attach_file!(@recording, filename: "clip.mp4", contents: "mp4", content_type: "video/mp4", actor: @actor)
    attach_file!(@recording, filename: "nested.zip", contents: "zip", content_type: "application/zip", actor: @actor)

    names = @recording.downloadable_files.map(&:filename)

    assert_equal %w[clip.mp4 doc.docx nested.zip notes.txt].sort, names.sort
  end

  test "excludes descendant attachments and trashed attachments" do
    folder = Folder.create!(name: "Nested #{SecureRandom.hex(4)}")
    folder_recording = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: @recording,
      parent_recording: @recording,
      actor: @actor
    ).recording

    attach_file!(@recording, filename: "direct.txt", contents: "direct", actor: @actor)
    attach_file!(folder_recording, filename: "child.txt", contents: "child", actor: @actor)
    trashed = attach_file!(@recording, filename: "gone.txt", contents: "gone", actor: @actor)
    trashed.update!(trashed_at: Time.current)

    names = @recording.downloadable_files.map(&:filename)

    assert_equal ["direct.txt"], names
  end

  test "empty source set is exposed cleanly" do
    assert_predicate @recording.downloadable_files, :empty?
    assert @recording.downloadable_empty?
    assert_nil @recording.downloadable_generate!
    refute @recording.downloadable_ready?
  end
end

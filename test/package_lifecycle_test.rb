# frozen_string_literal: true

require_relative "downloadable_test_helper"

class PackageLifecycleTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  setup do
    @actor = User.create!(email: "pkg-#{SecureRandom.hex(4)}@example.com", password: "Password", password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
    attach_file!(@recording, filename: "a.txt", contents: "aaa", actor: @actor)
  end

  test "generate moves pending to processing to ready and stores the archive" do
    package = @recording.downloadable_generate!

    assert_includes %w[pending processing], package.state

    perform_enqueued_jobs

    assert @recording.reload.downloadable_ready?
    assert @recording.downloadable_package.ready?
    assert @recording.downloadable_package.archive.attached?
    assert_equal "application/zip", @recording.downloadable_package.archive.content_type
  end

  test "reuses a valid package for the same fingerprint" do
    first = nil
    perform_enqueued_jobs { first = @recording.downloadable_generate! }

    assert_no_enqueued_jobs do
      second = @recording.downloadable_generate!
      assert_equal first.id, second.id
      assert second.ready?
    end
  end

  test "stale fingerprint enqueues regeneration" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "b.txt", contents: "bbb", actor: @actor)

    perform_enqueued_jobs do
      package = @recording.downloadable_generate!
      assert @recording.reload.downloadable_ready?
      assert_equal RecordingStudioDownloadable::Fingerprint.call(@recording.downloadable_files),
                   package.reload.source_fingerprint
    end
  end

  test "duplicate generate clicks do not enqueue identical concurrent jobs" do
    first = @recording.downloadable_generate!
    second = @recording.downloadable_generate!

    assert_equal first.id, second.id
    assert_equal 1, enqueued_jobs.size
  end

  test "failed generation stores the failure message" do
    package = @recording.downloadable_generate!
    package.update!(state: "processing")

    RecordingStudioDownloadable::Services::CollectFiles.stub :call, ->(*) { raise RecordingStudioDownloadable::SourceMissingError, "blob gone" } do
      result = RecordingStudioDownloadable::Services::GeneratePackage.call(package: package.reload)
      assert result.failure?
    end

    assert package.reload.failed?
    assert_includes package.failure_message, "blob gone"
  end
end

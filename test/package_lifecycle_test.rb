# frozen_string_literal: true

require_relative "downloadable_test_helper"

class PackageLifecycleTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  setup do
    @actor = User.create!(email: "pkg-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
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

    assert @recording.downloadable_stale?
    refute @recording.downloadable_ready?

    perform_enqueued_jobs do
      package = @recording.downloadable_generate!
      assert @recording.reload.downloadable_ready?
      refute @recording.downloadable_stale?
      assert_equal @recording.downloadable_source_fingerprint,
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
    ActiveStorage::Blob.find_each { |blob| blob.service.delete(blob.key) }

    result = RecordingStudioDownloadable::Services::GeneratePackage.call(package: package.reload)

    assert result.failure?
    assert package.reload.failed?
    assert_includes package.failure_message.downcase, "missing"
  end

  test "oversize archives fail generation without serving a zip" do
    previous = RecordingStudioDownloadable.configuration.max_zip_bytes
    RecordingStudioDownloadable.configuration.max_zip_bytes = 1

    perform_enqueued_jobs { @recording.downloadable_generate! }

    package = @recording.reload.downloadable_package
    assert package.failed?
    assert_includes package.failure_message, "too large"
    refute package.archive.attached?
    refute @recording.downloadable_ready?
  ensure
    RecordingStudioDownloadable.configuration.max_zip_bytes = previous
  end
end

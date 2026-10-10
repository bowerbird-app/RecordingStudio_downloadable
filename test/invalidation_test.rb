# frozen_string_literal: true

require_relative "downloadable_test_helper"

class InvalidationTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  setup do
    @actor = User.create!(email: "inv-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
    attach_file!(@recording, filename: "a.txt", contents: "aaa", actor: @actor)
  end

  test "asset removal invalidates immediately so the old zip is not ready" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    assert @recording.reload.downloadable_ready?
    old_fingerprint = @recording.downloadable_package.source_fingerprint

    attachment_recording = RecordingStudio::Recording.find_by!(
      parent_recording: @recording,
      recordable_type: "RecordingStudioAttachable::Attachment",
      trashed_at: nil
    )
    attachment_recording.update!(trashed_at: Time.current)

    @recording.reload
    refute @recording.downloadable_ready?
    refute_equal old_fingerprint, @recording.downloadable_source_fingerprint
  end

  test "immediate invalidate does not serve a previously ready archive" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    package = @recording.downloadable_package
    old_fingerprint = package.source_fingerprint

    @recording.downloadable_invalidate!(immediate: true, enqueue: false)

    refute @recording.reload.downloadable_ready?
    refute_equal old_fingerprint, package.reload.source_fingerprint
    refute @recording.downloadable_current_fingerprint_matches?(package.reload)
  end

  test "visibility change via invalidate immediate marks the package unusable" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    @recording.downloadable_invalidate!(immediate: true, enqueue: false)

    refute @recording.reload.downloadable_ready?
    assert @recording.downloadable_stale? || @recording.downloadable_package.source_fingerprint.blank?
  end

  test "ordinary content changes debounce a rebuild between 30 and 60 seconds" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    wait = RecordingStudioDownloadable.configuration.debounce_wait

    assert_operator wait, :>=, 30.seconds
    assert_operator wait, :<=, 60.seconds

    freeze_time do
      assert_enqueued_with(job: RecordingStudioDownloadable::GeneratePackageJob, at: Time.current + wait) do
        @recording.downloadable_invalidate!(immediate: false)
      end
    end

    refute @recording.reload.downloadable_ready?
  end
end

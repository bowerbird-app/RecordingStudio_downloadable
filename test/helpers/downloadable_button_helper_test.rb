# frozen_string_literal: true

require_relative "../downloadable_test_helper"

class DownloadableButtonHelperTest < ActionView::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper
  include RecordingStudioDownloadable::ApplicationHelper

  setup do
    @actor = User.create!(email: "btn-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @actor)
    Current.actor = @actor if defined?(Current)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "pending package button polls status instead of linking the zip" do
    @recording.downloadable_generate!
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "recording-studio-downloadable--package"
    assert_match(/<span>Preparing/, html)
    assert_includes html, "package/status"
    refute_includes html, "data-turbo-method"
  end

  test "failed package button is a retry post" do
    RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      format: "zip",
      state: "failed",
      failure_message: "Source set is empty"
    )
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Retry download"
    assert_includes html, "turbo-method"
    refute_match(/<span>Preparing/, html)
  end

  test "ready package button is a turbo-free zip get" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Download"
    assert_includes html, "data-turbo=\"false\""
    assert_includes html, "recording-studio-downloadable--package"
    assert_includes html, "startDownload"
    refute_match(/<span>Preparing/, html)
    refute_includes html, "package-poll-value=\"true\""
  end

  test "stale ready-state package uses generate post not a raw zip get" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @actor)
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Download"
    assert_includes html, "turbo-method"
    assert_includes html, "startDownload"
    refute_match(/<span>Preparing/, html)
  end

  test "anonymous visitors do not get a generate post when the audience is granted" do
    Current.actor = nil
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Download"
    refute_includes html, "turbo-method"
    assert_includes html, "can-generate-value=\"false\""
  end

  test "anonymous visitors get a generate post when the audience is public" do
    audience = {
      allowed: %i[public granted],
      default: :public,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
    with_action_audience(:"workspaces.download", audience) do
      Current.actor = nil
      html = recording_studio_downloadable_button(@recording.reload)

      assert_includes html, "Download"
      assert_includes html, "turbo-method"
      assert_includes html, "can-generate-value=\"true\""
    end
  end
end

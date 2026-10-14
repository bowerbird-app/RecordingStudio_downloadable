# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DownloadHistoryPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "history-page-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @workspace = Workspace.create!(name: "Studio Workspace #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @recording, actor: @user)
    @locked = Workspace.create!(name: "Locked Workspace #{SecureRandom.hex(4)}")
    @locked_recording = RecordingStudio.root_recording_for(@locked)
    sign_in @user
  end

  test "the dummy registers a denied component and the home page can show it" do
    component = RecordingStudioDownloadable.configuration.access_denied_component_for(:"workspaces.download")

    assert_equal DownloadAccessComponent, component

    studio = Workspace.find_or_create_by!(name: "Studio Workspace")
    studio_recording = RecordingStudio.root_recording_for(studio)
    grant_studio_download_access!(studio_recording, @user)
    locked_workspace = Workspace.find_or_create_by!(name: "Locked Workspace")
    RecordingStudio.root_recording_for(locked_workspace)

    get root_path

    assert_response :success
    assert_includes response.body, "Download"
    assert_includes response.body, "History"
    assert_includes response.body, "Ask for access"
    assert_includes response.body, "Locked Workspace"
  end

  test "history page renders stats for seeded-style rows" do
    colleague = User.create!(email: "colleague-#{SecureRandom.hex(4)}@example.com", password: "Password",
                             password_confirmation: "Password")
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: @recording.downloadable_action, export_scope: "public",
      actor: @user, occurred_at: 1.day.ago, ip_address: "203.0.113.10", user_agent: "StudioBrowser/1.0"
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: @recording.downloadable_action, export_scope: "public",
      actor: colleague, occurred_at: 2.days.ago
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: @recording.downloadable_action, export_scope: "public",
      actor: nil, occurred_at: 3.days.ago, ip_address: "198.51.100.8", user_agent: "AnonymousBrowser/1.0"
    )

    get recording_studio_downloadable.recording_download_logs_path(@recording)

    assert_response :success
    assert_includes response.body, "Download history"
    assert_includes response.body, "All time"
    assert_includes response.body, "Last 30 days"
    assert_includes response.body, "People"
    assert_includes response.body, @user.email
    assert_includes response.body, "Anonymous"
    refute_includes response.body, "203.0.113.10"
    refute_includes response.body, "AnonymousBrowser/1.0"
  end
end

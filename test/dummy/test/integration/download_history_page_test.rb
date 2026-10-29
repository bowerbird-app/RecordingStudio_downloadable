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
      actor: @user, occurred_at: 1.day.ago, ip_address: "203.0.113.10", user_agent: "StudioBrowser/1.0",
      metadata: { "recipient" => "zigzag-recipient", "confirmed" => true }
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: @recording.downloadable_action, export_scope: "public",
      actor: colleague, occurred_at: 2.days.ago
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: @recording.downloadable_action, export_scope: "public",
      actor: nil, occurred_at: 3.days.ago, ip_address: "198.51.100.8", user_agent: "AnonymousBrowser/1.0"
    )

    get recording_studio_admin_admin.screen_path("download_logs", recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Download history"
    assert_includes response.body, "Last 4 weeks"
    assert_includes response.body, "Last 12 months"
    refute_includes response.body, "People"
    refute_includes response.body, 'name="recordable_type"'
    refute_includes response.body, 'name="start_date"'

    get recording_studio_admin_admin.screen_table_path("download_logs", recording_id: @recording.id),
        headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, @user.email
    assert_includes response.body, "Anonymous"
    refute_includes response.body, ">Download<"
    refute_includes response.body, "203.0.113.10"
    refute_includes response.body, "AnonymousBrowser/1.0"
    refute_includes response.body, "zigzag-recipient"

    get recording_studio_admin_admin.screen_chart_path("download_logs", recording_id: @recording.id),
        headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    assert_includes response.body, "Downloads over time"
  end

  test "subtree history on a workspace lists a child kit download" do
    kit = PressKit.create!(name: "Subtree kit #{SecureRandom.hex(4)}")
    kit_recording = RecordingStudio.record!(
      action: "created",
      recordable: kit,
      root_recording: @recording,
      parent_recording: @recording,
      actor: @user
    ).recording
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: kit_recording, action: "press_kits.download", export_scope: "public",
      actor: @user, occurred_at: 1.day.ago
    )

    get recording_studio_admin_admin.screen_path(
      "download_logs",
      recording_id: @recording.id,
      scope: "subtree"
    )

    assert_response :success
    assert_includes response.body, 'name="recordable_type"'
    assert_includes response.body, ">What<"

    get recording_studio_admin_admin.screen_table_path(
      "download_logs",
      recording_id: @recording.id,
      scope: "subtree"
    ), headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, kit.name
    assert_includes response.body, @user.email
    assert_includes response.body, "What"

    get recording_studio_admin_admin.screen_path(
      "download_logs",
      recording_id: @recording.id,
      scope: "subtree",
      recordable_type: "PressKit"
    )

    assert_response :success
    assert_match(/value="PressKit" selected="selected"/, response.body)
  end
end

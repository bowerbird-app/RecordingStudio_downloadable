# frozen_string_literal: true

require_relative "downloadable_test_helper"

class DownloadHistoryTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @admin = User.create!(email: "hist-admin-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @editor = User.create!(email: "hist-edit-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @viewer = User.create!(email: "hist-view-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @admin)
    grant_role!(@recording, @editor, :edit)
    grant_role!(@recording, @viewer, :view)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @admin)
  end

  test "edit and admin can open history and view cannot" do
    sign_in @admin
    get history_path
    assert_response :success

    sign_in @editor
    get history_path
    assert_response :success

    sign_in @viewer
    get history_path
    assert_response :forbidden
  end

  test "a viewer who can download still cannot open history" do
    perform_enqueued_jobs_download!
    sign_in @viewer

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_response :redirect

    get history_path
    assert_response :forbidden
  end

  test "anonymous requests are forbidden" do
    get history_path

    assert_response :forbidden
  end

  test "history stays on this recording and hides ip and user agent" do
    other = create_workspace_recording
    grant_download_access!(other, @admin)
    secret_ip = "203.0.113.55"
    secret_agent = "SecretAgentToken/#{SecureRandom.hex(4)}"
    log_download!(@recording, actor: @admin, ip_address: secret_ip, user_agent: secret_agent, occurred_at: 1.hour.ago)
    log_download!(other, actor: @admin, action: "workspaces.other-only", occurred_at: 1.hour.ago)

    sign_in @admin
    get history_path

    assert_response :success
    assert_includes response.body, @admin.email
    assert_includes response.body, @recording.downloadable_action.to_s
    refute_includes response.body, "workspaces.other-only"
    refute_includes response.body, secret_ip
    refute_includes response.body, secret_agent
  end

  test "empty history shows the empty state and zero stats" do
    sign_in @admin
    get history_path

    assert_response :success
    assert_includes response.body, "No downloads yet."
    assert_includes response.body, "All time"
    assert_includes response.body, "Last 30 days"
    assert_includes response.body, "People"
  end

  test "stats count the window and skip anonymous people" do
    log_download!(@recording, actor: @admin, occurred_at: 1.day.ago)
    log_download!(@recording, actor: @admin, occurred_at: 2.days.ago)
    log_download!(@recording, actor: @editor, occurred_at: 3.days.ago)
    log_download!(@recording, actor: nil, occurred_at: 4.days.ago)
    log_download!(@recording, actor: @viewer, occurred_at: 45.days.ago)

    stats = RecordingStudioDownloadable::DownloadStats.new(@recording)

    assert_equal 5, stats.total
    assert_equal 4, stats.last_30_days
    assert_equal 3, stats.identified_people

    sign_in @admin
    get history_path

    assert_includes response.body, "Anonymous"
    assert_includes response.body, @viewer.email
  end

  test "filters limit the table and pagination keeps the oldest row on the next page" do
    log_download!(@recording, actor: nil, action: "workspaces.archive", occurred_at: 10.days.ago)
    log_download!(@recording, actor: @admin, occurred_at: 60.days.ago)
    21.times do |index|
      log_download!(
        @recording,
        actor: @editor,
        action: index == 20 ? "workspaces.page-two" : "workspaces.download",
        occurred_at: index.minutes.ago
      )
    end

    sign_in @admin
    get history_path, params: { download: "workspaces.archive" }
    assert_includes history_table, "workspaces.archive"
    assert_includes history_table, "Anonymous"
    refute_includes history_table, "workspaces.page-two"

    get history_path, params: { person: "anonymous" }
    assert_includes history_table, "Anonymous"
    assert_includes history_table, "workspaces.archive"
    refute_includes history_table, "workspaces.page-two"

    get history_path, params: { from: 20.days.ago.to_date.iso8601, to: 5.days.ago.to_date.iso8601 }
    assert_includes history_table, "workspaces.archive"
    refute_includes history_table, "workspaces.page-two"

    get history_path, params: { page: 2 }
    assert_response :success
    assert_includes response.body, "workspaces.page-two"
  end

  test "hosts can override history through an action audience" do
    with_action_audience(:"downloadable.view_logs", admin_only_audience) do
      sign_in @editor
      get history_path
      assert_response :forbidden

      sign_in @admin
      get history_path
      assert_response :success
    end
  ensure
    # Setting an audience replaces the default edit policy. Restoring the hash
    # does not put that policy back, so later examples would all be forbidden.
    restore_view_logs_policy!
  end

  private

  def history_path
    recording_studio_downloadable.recording_download_logs_path(@recording)
  end

  def history_table
    response.body[%r{<tbody.*?</tbody>}m].to_s
  end

  def log_download!(recording, actor:, action: "workspaces.download", occurred_at: Time.current, **trace)
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: recording,
      action: action,
      export_scope: "public",
      actor: actor,
      occurred_at: occurred_at,
      ip_address: trace[:ip_address],
      user_agent: trace[:user_agent]
    )
  end

  def grant_role!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @admin
    )
    raise result.error if result.failure?
  end

  def perform_enqueued_jobs_download!
    sign_in @admin
    perform_enqueued_jobs { @recording.downloadable_generate! }
  end

  def restore_view_logs_policy!
    RecordingStudioAccessible.define_action(:"downloadable.view_logs") do |actor:, recording:, **|
      next false if actor.nil? || recording.nil?

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
    end
  end

  def admin_only_audience
    {
      allowed: %i[granted],
      default: :granted,
      granted_roles: %i[admin],
      granted_override: true,
      manage_role: :admin
    }
  end
end

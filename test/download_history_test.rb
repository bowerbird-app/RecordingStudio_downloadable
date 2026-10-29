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
    assert_response :not_found
  end

  test "a viewer who can download still cannot open history" do
    perform_enqueued_jobs_download!
    sign_in @viewer

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_response :redirect

    get history_path
    assert_response :not_found
  end

  test "anonymous requests are sent to sign in" do
    get history_path

    assert_response :redirect
    assert_match %r{/users/sign_in}, response.location
  end

  test "history stays on this recording and hides ip and user agent" do
    other = create_workspace_recording
    secret_ip = "203.0.113.55"
    secret_agent = "SecretAgentToken/#{SecureRandom.hex(4)}"
    log_download!(@recording, actor: @admin, ip_address: secret_ip, user_agent: secret_agent, occurred_at: 1.hour.ago)
    log_download!(other, actor: @admin, action: "workspaces.other-only", occurred_at: 1.hour.ago)

    sign_in @admin
    fetch_table

    assert_response :success
    assert_includes history_table, @admin.email
    refute_includes history_table, @recording.downloadable_action.to_s
    refute_includes table_headers, "Download"
    refute_includes history_table, "workspaces.other-only"
    refute_includes history_table, secret_ip
    refute_includes history_table, secret_agent
  end

  test "empty history shows the admin summary and no rows" do
    sign_in @admin
    get history_path

    assert_response :success
    assert_includes response.body, "Download history"
    assert_includes response.body, "Last 4 weeks"
    assert_includes response.body, "All time"
    assert_match(/value="last_4_weeks" selected="selected"/, response.body)
    refute_includes response.body, "People"
    refute_includes response.body, 'name="recordable_type"'
    refute_includes response.body, 'name="start_date"'
    refute_includes response.body, 'name="download"'

    fetch_chart
    assert_response :success
    assert_includes response.body, "Downloads over time"
  end

  test "the chart counts the default four week window" do
    log_download!(@recording, actor: @admin, occurred_at: 1.day.ago)
    log_download!(@recording, actor: @admin, occurred_at: 2.days.ago)
    log_download!(@recording, actor: @editor, occurred_at: 3.days.ago)
    log_download!(@recording, actor: nil, occurred_at: 4.days.ago)
    log_download!(@recording, actor: @viewer, occurred_at: 45.days.ago)

    sign_in @admin
    get history_path
    assert_includes response.body, "Last 4 weeks"

    fetch_table
    assert_includes history_table, "Anonymous"
    refute_includes history_table, @viewer.email

    fetch_chart
    assert_includes response.body, "Downloads over time"
    assert_includes response.body, ">4<"
    assert_match(/flat-pack--chart-series-value=.*&quot;x&quot;:/, response.body)
    assert_match(/flat-pack--chart-series-value=.*&quot;y&quot;:1/, response.body)
    refute_match(/flat-pack--chart-series-value=.*\[\d{4}-\d{2}-\d{2}/, response.body)
  end

  test "period presets and person filters limit the table" do
    log_download!(@recording, actor: nil, occurred_at: 10.days.ago)
    log_download!(@recording, actor: @viewer, occurred_at: 400.days.ago)
    21.times do |index|
      log_download!(@recording, actor: @editor, occurred_at: index.minutes.ago)
    end

    sign_in @admin
    fetch_table(person: "anonymous")
    assert_includes history_table, "Anonymous"
    refute_includes history_table, @editor.email

    fetch_table(period: "last_7_days")
    assert_includes history_table, @editor.email
    refute_includes history_table, "Anonymous"

    fetch_table(period: "all_time", page: 2)
    assert_response :success
    assert_includes history_table, "Anonymous"
    assert_includes history_table, @viewer.email
  end

  test "all time chart stays inside the metrics reporting limit" do
    log_download!(@recording, actor: @viewer, occurred_at: 400.days.ago)
    log_download!(@recording, actor: @editor, occurred_at: 1.day.ago)

    sign_in @admin
    fetch_chart(period: "all_time")

    assert_response :success
    assert_includes response.body, "Downloads over time"
    refute_includes response.body, "InvalidDateRange"
  end

  test "another recording's logs stay closed" do
    other = create_workspace_recording
    log_download!(other, actor: @admin, action: "workspaces.other-only", occurred_at: 1.hour.ago)

    sign_in @admin
    get table_path(other)

    assert_includes [403, 404], response.status
    refute_includes response.body, "workspaces.other-only"
  end

  test "subtree history includes child logs and excludes siblings" do
    child = record_child!(PressKit.create!(name: "Launch kit"), parent: @recording)
    sibling = create_workspace_recording
    grant_download_access!(sibling, @admin)
    log_download!(@recording, actor: @admin, occurred_at: 1.hour.ago)
    log_download!(child, actor: @editor, action: "press_kits.download", occurred_at: 2.hours.ago)
    log_download!(sibling, actor: @admin, action: "workspaces.sibling-only", occurred_at: 1.hour.ago)

    sign_in @admin
    fetch_table
    refute_includes table_headers, "What"
    refute_includes history_table, "Launch kit"
    refute_includes history_table, "workspaces.sibling-only"

    fetch_table(scope: "subtree", recording_ids: [sibling.id])
    assert_includes table_headers, "What"
    assert_includes history_table, @admin.email
    assert_includes history_table, @editor.email
    assert_includes history_table, "Launch kit"
    refute_includes history_table, "workspaces.sibling-only"
    refute_includes history_table, sibling.name
  end

  test "subtree type filter keeps matching children and drops other types" do
    kit = record_child!(PressKit.create!(name: "Typed kit"), parent: @recording)
    page = record_child!(Page.create!(title: "Typed page"), parent: @recording)
    log_download!(kit, actor: @admin, action: "press_kits.download", occurred_at: 1.hour.ago)
    log_download!(page, actor: @editor, action: "pages.download", occurred_at: 1.hour.ago)

    sign_in @admin
    fetch_table(scope: "subtree", recordable_type: "PressKit")
    assert_includes history_table, "Typed kit"
    refute_includes history_table, "Typed page"

    fetch_table(scope: "subtree")
    assert_includes history_table, "Typed kit"
    assert_includes history_table, "Typed page"

    fetch_table(scope: "subtree", recordable_type: "NotAType")
    refute_includes history_table, "Typed kit"
    refute_includes history_table, "Typed page"
  end

  test "subtree history shows a What filter and item history does not" do
    kit = record_child!(PressKit.create!(name: "Filter kit"), parent: @recording)
    record_child!(Page.create!(title: "Filter page"), parent: @recording)
    log_download!(kit, actor: @admin, action: "press_kits.download", occurred_at: 1.hour.ago)

    sign_in @admin
    get history_path
    refute_includes response.body, 'name="recordable_type"'

    get screen_path(@recording, scope: "subtree")
    assert_includes response.body, 'name="recordable_type"'
    assert_includes response.body, ">What<"
    assert_includes response.body, 'value="PressKit"'
    assert_includes response.body, 'value="Page"'
    refute_match(/value="PressKit" selected="selected"/, response.body)

    get screen_path(@recording, scope: "subtree", recordable_type: "PressKit")
    assert_match(/value="PressKit" selected="selected"/, response.body)
  end

  test "subtree history still requires view_logs on the anchor" do
    child = record_child!(PressKit.create!(name: "Hidden kit"), parent: @recording)
    log_download!(child, actor: @admin, action: "press_kits.download", occurred_at: 1.hour.ago)

    sign_in @viewer
    get table_path(@recording, scope: "subtree")
    assert_response :not_found
    refute_includes response.body, "Hidden kit"
  end

  test "hosts can override history through an action audience" do
    with_action_audience(:"downloadable.view_logs", admin_only_audience) do
      sign_in @editor
      get history_path
      assert_response :not_found

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
    screen_path(@recording)
  end

  def screen_path(recording, extra = {})
    recording_studio_admin_admin.screen_path(screen_key, extra.merge(recording_id: recording.id))
  end

  def fetch_table(extra = {})
    get table_path(@recording, extra), headers: { "Turbo-Frame" => "screen-table" }
  end

  def fetch_chart(extra = {})
    get recording_studio_admin_admin.screen_chart_path(screen_key, extra.merge(recording_id: @recording.id)),
        headers: { "Turbo-Frame" => "screen-chart" }
  end

  def table_headers
    response.body[%r{<thead.*?</thead>}m].to_s
  end

  def table_path(recording, extra = {})
    recording_studio_admin_admin.screen_table_path(screen_key, extra.merge(recording_id: recording.id))
  end

  def screen_key
    RecordingStudioDownloadable::Admin::SCREEN_KEY
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

  def record_child!(recordable, parent:)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: parent.root_recording_or_self,
      parent_recording: parent,
      actor: @admin
    ).recording
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

# frozen_string_literal: true

require_relative "downloadable_test_helper"

class StatsGateTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include RecordingStudioDownloadable::ApplicationHelper

  setup do
    RecordingStudio::Gates.reset!
    @owner = User.create!(email: "stats-owner-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @editor = User.create!(email: "stats-edit-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @viewer = User.create!(email: "stats-view-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @recording = create_workspace_recording(name: "Stats #{SecureRandom.hex(4)}")
    grant_download_access!(@recording, @owner)
    grant_role!(@recording, @editor, :edit)
    grant_role!(@recording, @viewer, :view)
  end

  teardown do
    RecordingStudio::Gates.reset!
    Current.actor = nil if defined?(Current)
  end

  test "an unregistered stats gate leaves history and metrics on the view logs check" do
    sign_in @editor
    get history_path
    assert_response :success
    assert_select "h1", text: "Downloads"

    get rollup_path
    assert_response :success

    assert_equal "history-link", history_link(@recording, @editor)
    assert metrics_allowed?(@editor, @recording)
    refute metrics_allowed?(@viewer, @recording)
    refute metrics_allowed?(nil, @recording)
    assert_nil history_link(@recording, nil)

    sign_in @viewer
    get history_path
    assert_response :not_found

    sign_out @viewer
    get history_path
    assert_response :redirect
    assert_match %r{/users/sign_in}, response.location
  end

  test "an allowing stats gate keeps editors and still denies viewers and a nil recording" do
    called = false
    RecordingStudio.register_gate("downloadable.stats", :plan) do
      called = true
      true
    end

    refute RecordingStudioDownloadable::Authorization.view_logs_allowed?(actor: @editor, recording: nil)
    refute called

    refute RecordingStudioDownloadable::Authorization.view_logs_allowed?(actor: nil, recording: @recording)
    refute called

    sign_in @editor
    get history_path
    assert_response :success
    assert_equal "history-link", history_link(@recording, @editor)
    assert metrics_allowed?(@editor, @recording)

    sign_in @viewer
    get history_path
    assert_response :not_found
    assert_nil history_link(@recording, @viewer)
    refute metrics_allowed?(@viewer, @recording)
  end

  test "a denying stats gate hides history screens, the history link, and metrics" do
    RecordingStudio.register_gate("downloadable.stats", :plan) { false }

    sign_in @editor
    get history_path
    assert_response :not_found

    get rollup_path
    assert_response :not_found

    assert_nil history_link(@recording, @editor)
    refute metrics_allowed?(@editor, @recording)
    refute metrics_allowed?(nil, @recording)
  end

  test "a stats gate redirect sends html history requests and leaves json and metrics denied" do
    RecordingStudio.register_gate("downloadable.stats", :plan) do
      RecordingStudio::GateDecision.deny(redirect_to: "/billing")
    end

    sign_in @editor
    get history_path
    assert_redirected_to "/billing"

    get rollup_path
    assert_redirected_to "/billing"

    get recording_studio_admin_admin.screen_chart_path("download_logs", recording_id: @recording.id)
    assert_redirected_to "/billing"

    get recording_studio_admin_admin.screen_table_path("download_logs", recording_id: @recording.id)
    assert_redirected_to "/billing"

    get history_path, as: :json
    assert_response :not_found

    refute metrics_allowed?(@editor, @recording)
    assert_nil history_link(@recording, @editor)
  end

  test "a raising stats gate denies history without redirecting" do
    RecordingStudio.register_gate("downloadable.stats", :plan) { raise "billing down" }

    sign_in @editor
    get history_path
    assert_response :not_found
    refute metrics_allowed?(@editor, @recording)

    sign_out @editor
    get history_path
    assert_response :redirect
    assert_match %r{/users/sign_in}, response.location
  end

  test "an anonymous request still signs in when the stats gate would redirect" do
    RecordingStudio.register_gate("downloadable.stats", :plan) do
      RecordingStudio::GateDecision.deny(redirect_to: "/billing")
    end

    get history_path
    assert_response :redirect
    assert_match %r{/users/sign_in}, response.location
    refute_equal "/billing", response.location
  end

  def render(*_args)
    "history-link"
  end

  private

  def history_path
    recording_studio_admin_admin.screen_path("download_logs", recording_id: @recording.id)
  end

  def rollup_path
    recording_studio_admin_admin.screen_path("download_logs_rollup", recording_id: @recording.id)
  end

  def history_link(recording, actor)
    Current.actor = actor
    recording_studio_downloadable_history_link(recording)
  end

  def metrics_allowed?(actor, recording)
    hook = RecordingStudioMetrics.registry.api_authorize_for(:download_logs)
    grant = Struct.new(:actor, :access_recording).new(actor, recording)
    hook.call(Struct.new(:access_grant).new(grant))
  end

  def grant_role!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end
end

# frozen_string_literal: true

require_relative "downloadable_test_helper"

class LogsRegistrationTest < ActiveSupport::TestCase
  include DownloadableTestHelper

  setup do
    @previous_flag = RecordingStudioDownloadable.configuration.logs_summaries_enabled
    RecordingStudioDownloadable.configuration.logs_summaries_enabled = false
    RecordingStudioDownloadable::LogsRegistration.register!
    @user = User.create!(email: "logs-reg-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
  end

  teardown do
    RecordingStudioDownloadable.configuration.logs_summaries_enabled = @previous_flag
    RecordingStudioDownloadable::LogsRegistration.register!
  end

  test "registers the existing download log as an unpartitioned indefinite Logs source" do
    log = RecordingStudioLogs.registry.log_for(RecordingStudioDownloadable::LogsRegistration::SOURCE_MODEL)

    assert log
    assert_equal :occurred_at, log.timestamp_column
    assert_nil log.partition_interval
    assert_equal :root_recording_id, log.root_column
    assert_predicate log, :indefinite?
    assert_equal "recording_studio_downloadable_download_logs",
                 RecordingStudioDownloadable::DownloadLog.table_name
    refute_includes connection_table_options, "PARTITION BY"
  end

  test "registers a daily download count aggregation" do
    aggregation = RecordingStudioDownloadable::LogsRegistration.download_counts_definition

    assert_equal "downloadable/download_counts", aggregation.name
    assert_equal %i[root_recording_id recording_id], aggregation.group_by
    assert_equal RecordingStudioDownloadable::DownloadDaySummary, aggregation.summary_model
  end

  test "summaries stay off by default and metrics still read raw download logs" do
    refute RecordingStudioDownloadable::LogsRegistration.summaries_enabled?

    definition = RecordingStudioMetrics.find(RecordingStudioDownloadable::MetricsRegistration::TOTAL_METRIC)

    assert definition
    assert_equal RecordingStudioDownloadable::DownloadLog, definition.model
    assert_equal RecordingStudioDownloadable::DownloadLog,
                 RecordingStudioMetrics.find(
                   RecordingStudioDownloadable::MetricsRegistration::TIMESERIES_METRIC
                 ).model
  end

  test "rebuilding a UTC day writes summary rows that match the raw count" do
    RecordingStudioDownloadable.configuration.logs_summaries_enabled = true
    day = Date.new(2026, 10, 14)
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: "workspaces.download", export_scope: "public",
      actor: @user, occurred_at: Time.utc(2026, 10, 14, 9, 0, 0)
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: "workspaces.download", export_scope: "public",
      actor: @user, occurred_at: Time.utc(2026, 10, 14, 18, 0, 0)
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: "workspaces.download", export_scope: "public",
      actor: @user, occurred_at: Time.utc(2026, 10, 15, 1, 0, 0)
    )

    RecordingStudioDownloadable::Services::RebuildDownloadLogSummaries.call(day: day)

    rows = RecordingStudioDownloadable::DownloadDaySummary.where(
      day: day,
      recording_id: @recording.id
    )
    assert_equal 1, rows.count
    assert_equal 2, rows.sole.download_count
    assert_equal @recording.id, rows.sole.root_recording_id
  end

  test "flag off leaves Admin history on the raw log relation" do
    refute RecordingStudioDownloadable::LogsRegistration.summaries_enabled?

    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: "workspaces.download", export_scope: "public", actor: @user
    )

    relation = @recording.downloadable_download_logs
    assert_equal 1, relation.count
    assert_equal RecordingStudioDownloadable::DownloadLog, relation.klass
  end

  private

  def connection_table_options
    result = RecordingStudioDownloadable::DownloadLog.connection.select_one(<<~SQL.squish)
      SELECT relkind, relispartition
      FROM pg_class
      WHERE relname = 'recording_studio_downloadable_download_logs'
    SQL
    result.to_h.inspect
  end
end

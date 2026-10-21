# frozen_string_literal: true

require_relative "downloadable_test_helper"

class LogsRegistrationTest < ActiveSupport::TestCase
  include DownloadableTestHelper

  setup do
    RecordingStudioDownloadable::LogsRegistration.register!
    @user = User.create!(email: "logs-reg-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
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
    assert_empty RecordingStudioLogs.registry.aggregations_for(log)
  end

  test "metrics still read raw download logs" do
    definition = RecordingStudioMetrics.find(RecordingStudioDownloadable::MetricsRegistration::TOTAL_METRIC)

    assert definition
    assert_equal RecordingStudioDownloadable::DownloadLog, definition.model
    assert_equal RecordingStudioDownloadable::DownloadLog,
                 RecordingStudioMetrics.find(
                   RecordingStudioDownloadable::MetricsRegistration::TIMESERIES_METRIC
                 ).model
  end

  test "Admin history stays on the raw log relation" do
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

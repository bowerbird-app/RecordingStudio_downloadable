# frozen_string_literal: true

module RecordingStudioDownloadable
  module LogsRegistration
    SOURCE_MODEL = "RecordingStudioDownloadable::DownloadLog"
    DOWNLOAD_COUNTS = "downloadable/download_counts"
    OWNER = "RecordingStudioDownloadable"

    module_function

    def summaries_enabled?
      RecordingStudioDownloadable.configuration.logs_summaries_enabled
    end

    def logging_connection
      DownloadLog.connection
    end

    def register!
      return unless defined?(RecordingStudioLogs)

      RecordingStudioLogs.register(
        model: SOURCE_MODEL,
        timestamp_column: :occurred_at,
        partition_interval: nil,
        root_column: :root_recording_id,
        owner: OWNER,
        retention: :indefinite,
        aggregatable: {
          root_recording_id: { filter: [:eq], group: true },
          recording_id: { filter: [:eq], group: true }
        }
      )

      RecordingStudioLogs.aggregate(
        source: SOURCE_MODEL,
        name: DOWNLOAD_COUNTS,
        summary_model: "RecordingStudioDownloadable::DownloadDaySummary",
        owner: OWNER,
        group_by: %i[root_recording_id recording_id],
        measurements: {
          download_count: :count
        }
      )

      RecordingStudioLogs.finalize!
    end

    def download_counts_definition
      RecordingStudioLogs.registry.aggregation(DOWNLOAD_COUNTS)
    end
  end
end

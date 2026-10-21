# frozen_string_literal: true

module RecordingStudioDownloadable
  module LogsRegistration
    SOURCE_MODEL = "RecordingStudioDownloadable::DownloadLog"
    OWNER = "RecordingStudioDownloadable"
    AGGREGATABLE = {
      root_recording_id: { filter: [:eq], group: true },
      recording_id: { filter: [:eq], group: true }
    }.freeze

    module_function

    def register!
      return unless defined?(RecordingStudioLogs)

      register_source!
      RecordingStudioLogs.finalize!
    end

    def register_source!
      RecordingStudioLogs.register(
        model: SOURCE_MODEL,
        timestamp_column: :occurred_at,
        partition_interval: nil,
        root_column: :root_recording_id,
        owner: OWNER,
        retention: :indefinite,
        aggregatable: AGGREGATABLE
      )
    end
  end
end

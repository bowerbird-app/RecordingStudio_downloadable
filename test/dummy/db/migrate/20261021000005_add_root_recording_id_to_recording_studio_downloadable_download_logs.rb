# frozen_string_literal: true

class AddRootRecordingIdToRecordingStudioDownloadableDownloadLogs < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_downloadable_download_logs
  INDEX = "index_rs_download_logs_on_root_and_occurred_at"

  def up
    RecordingStudioLogs::Cutover.add_root_column(TABLE)
    RecordingStudioLogs::Cutover.backfill_root(TABLE)
    return if index_exists?(TABLE, %i[root_recording_id occurred_at], name: INDEX)

    RecordingStudioLogs::Schema.root_and_time_index(
      TABLE,
      root_column: :root_recording_id,
      timestamp_column: :occurred_at,
      name: INDEX
    )
  end

  def down
    remove_index TABLE, name: INDEX if index_exists?(TABLE, name: INDEX)
    remove_column TABLE, :root_recording_id if column_exists?(TABLE, :root_recording_id)
  end
end

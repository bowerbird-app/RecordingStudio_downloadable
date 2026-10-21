# frozen_string_literal: true

class CreateRecordingStudioDownloadableDownloadDaySummaries < ActiveRecord::Migration[8.1]
  TABLE = "recording_studio_downloadable_download_day_summaries"
  IDENTITY_INDEX = "index_rs_download_day_summaries_identity"

  def up
    RecordingStudioLogs::Schema.install_runs!(connection)

    return if connection.data_source_exists?(TABLE)

    create_table TABLE, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.date :day, null: false
      t.uuid :root_recording_id
      t.uuid :recording_id
      t.bigint :download_count, null: false, default: 0
      t.timestamps
    end
    RecordingStudioLogs::Schema.summary_index(
      TABLE,
      %i[day root_recording_id recording_id],
      name: IDENTITY_INDEX
    )
    add_index TABLE, %i[root_recording_id day], name: "index_rs_download_day_summaries_on_root_and_day"
    add_index TABLE, %i[recording_id day], name: "index_rs_download_day_summaries_on_recording_and_day"
  end

  def down
    drop_table TABLE if connection.data_source_exists?(TABLE)
  end
end

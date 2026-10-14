# frozen_string_literal: true

class CreateRecordingStudioDownloadableDownloadLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_downloadable_download_logs, id: :uuid do |t|
      t.references :recording, null: false, type: :uuid,
                               foreign_key: { to_table: :recording_studio_recordings }
      t.string :action, null: false
      t.string :export_scope, null: false, default: "public"
      t.string :actor_type
      t.uuid :actor_id
      t.string :impersonator_type
      t.uuid :impersonator_id
      t.string :ip_address
      t.string :user_agent
      t.datetime :occurred_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.datetime :created_at, null: false
    end

    add_index :recording_studio_downloadable_download_logs,
              %i[recording_id occurred_at created_at],
              order: { occurred_at: :desc, created_at: :desc },
              name: "index_rs_download_logs_on_recording_and_timeline"
    add_index :recording_studio_downloadable_download_logs,
              %i[action occurred_at],
              name: "index_rs_download_logs_on_action_and_occurred_at"
    add_index :recording_studio_downloadable_download_logs,
              %i[actor_type actor_id occurred_at],
              name: "index_rs_download_logs_on_actor_and_occurred_at"
  end
end

# frozen_string_literal: true

class AddMetadataToRecordingStudioDownloadableDownloadLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_downloadable_download_logs, :metadata, :jsonb, null: false, default: {}
  end
end

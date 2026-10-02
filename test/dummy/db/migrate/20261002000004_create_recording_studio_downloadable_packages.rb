# frozen_string_literal: true

class CreateRecordingStudioDownloadablePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_downloadable_packages, id: :uuid do |t|
      t.uuid :recording_id, null: false
      t.string :format, null: false, default: "zip"
      t.string :state, null: false, default: "pending"
      t.string :source_fingerprint
      t.text :failure_message

      t.timestamps
    end

    add_index :recording_studio_downloadable_packages,
              %i[recording_id format],
              unique: true,
              name: "idx_rs_downloadable_packages_on_recording_and_format"
    add_index :recording_studio_downloadable_packages, :state
  end
end

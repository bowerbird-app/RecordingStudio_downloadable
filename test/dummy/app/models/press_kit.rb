# frozen_string_literal: true

class PressKit < ApplicationRecord
  recording_studio_recordable label: "Press kit", root: false, allowed_parent_types: ["Workspace"]
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  RecordingStudio.enable_capability(:action_audiences, on: self) if defined?(RecordingStudioAccessible)

  validates :name, presence: true

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: ["image/*", "application/pdf", "text/plain", "*/*"],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[image file]
  )
  include RecordingStudio::Capabilities::Downloadable.to(source: :manifest, format: :zip)

  def downloadable_manifest
    stored = stored_download_files
    stored + generated_download_files(stored)
  end

  # Cheap status key. It must change when any file in the ZIP changes.
  # Action and export scope are part of the value; Downloadable mixes them
  # in again when it stores the key. Generated text always makes a kit non-empty.
  def downloadable_cache_key(action:, export_scope:)
    [action, export_scope, content_token, attachment_token].join("\u001f")
  end

  def downloadable_empty?
    false
  end

  private

  def content_token
    [updated_at&.utc&.iso8601(6), name, description, credits, created_at&.utc&.iso8601(6)].join("\u001f")
  end

  def attachment_token
    recording = RecordingStudio::Recording
      .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
      .find_by(recordable: self)
    return "none" unless recording

    sql = <<~SQL.squish
      SELECT md5(COALESCE(string_agg(
        r.id::text || ':' || b.id::text || ':' || COALESCE(b.checksum, '') || ':' ||
        COALESCE(a.original_filename, b.filename) || ':' || b.byte_size::text,
        ',' ORDER BY r.id::text
      ), ''))
      FROM recording_studio_recordings r
      INNER JOIN recording_studio_attachable_attachments a ON a.id = r.recordable_id
      INNER JOIN active_storage_attachments sa
        ON sa.record_type = 'RecordingStudioAttachable::Attachment'
       AND sa.record_id = a.id
       AND sa.name = 'file'
      INNER JOIN active_storage_blobs b ON b.id = sa.blob_id
      WHERE r.parent_recording_id = ?
        AND r.recordable_type = 'RecordingStudioAttachable::Attachment'
        AND r.trashed_at IS NULL
    SQL
    self.class.connection.select_value(self.class.sanitize_sql_array([sql, recording.id])).to_s
  end

  def stored_download_files
    recording = RecordingStudio::Recording
      .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
      .find_by(recordable: self)
    return [] unless recording

    RecordingStudioDownloadable::Sources::Attachments.call(recording)
  end

  def generated_download_files(stored)
    description_text = description.to_s
    credits_text = credits.to_s
    json = JSON.pretty_generate(
      name: name,
      description: description_text,
      files: stored.map(&:filename) + %w[description.txt credits.txt press-kit.json],
      generated_at: created_at&.iso8601
    )

    [
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "description.txt",
        content_type: "text/plain",
        content: description_text
      ),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "credits.txt",
        content_type: "text/plain",
        content: credits_text
      ),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "press-kit.json",
        content_type: "application/json",
        content: json
      )
    ]
  end
end

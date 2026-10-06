# frozen_string_literal: true

class PressKit < ApplicationRecord
  recording_studio_recordable label: "Press kit", root: false, allowed_parent_types: ["Workspace"]

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

  private

  def stored_download_files
    recording = RecordingStudio::Recording.find_by(recordable: self, trashed_at: nil)
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

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  validates :title, presence: true

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: [ "image/*", "application/pdf", "text/plain", "*/*" ],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[ image file ]
  )
  include RecordingStudio::Capabilities::Downloadable.to(source: :attachments, format: :zip)
end

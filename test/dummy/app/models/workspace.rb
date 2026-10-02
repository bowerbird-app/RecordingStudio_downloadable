class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: [ "image/*", "application/pdf", "text/plain", "application/zip",
                             "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                             "video/mp4", "audio/mpeg", "*/*" ],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[ image file ]
  )
  include RecordingStudio::Capabilities::Downloadable.to(source: :attachments, format: :zip)
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: [ "*/*" ],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[ image file ]
  )
end

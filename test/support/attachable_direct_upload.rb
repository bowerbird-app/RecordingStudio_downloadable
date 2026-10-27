# frozen_string_literal: true

require "digest"
require "stringio"

module AttachableDirectUpload
  module_function

  def upload!(recording:, actor:, filename:, content:, content_type: "text/plain")
    checksum = Digest::MD5.base64digest(content)
    blob = RecordingStudioAttachable::DirectUpload.prepare!(
      recording: recording,
      actor: actor,
      filename: filename,
      byte_size: content.bytesize,
      checksum: checksum,
      content_type: content_type
    )
    blob.upload(StringIO.new(content), identify: false)
    recording.record_attachment_upload(
      signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(blob),
      actor: actor,
      name: File.basename(filename, ".*").presence || filename
    )
  end
end

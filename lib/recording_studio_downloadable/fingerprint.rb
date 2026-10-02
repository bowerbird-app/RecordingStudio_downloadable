# frozen_string_literal: true

require "digest"

module RecordingStudioDownloadable
  module Fingerprint
    module_function

    def call(files)
      payload = Array(files).map do |file|
        [file.identity.to_s, file.checksum.to_s, file.byte_size.to_i, file.filename.to_s]
      end.sort

      Digest::SHA256.hexdigest(payload.inspect)
    end
  end
end

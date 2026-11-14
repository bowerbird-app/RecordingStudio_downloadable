# frozen_string_literal: true

require "digest"

module RecordingStudioDownloadable
  module Fingerprint
    module_function

    def call(files, action: nil, export_scope: nil)
      payload = Array(files).map do |file|
        [file.identity.to_s, file.checksum.to_s, file.byte_size.to_i, file.filename.to_s]
      end.sort
      payload << ["action", action.to_s]
      payload << ["export_scope", export_scope.to_s]

      Digest::SHA256.hexdigest(payload.inspect)
    end

    # Mix the host cache key with the package identity. The host value has to
    # change when any ZIP file changes. Action and export scope are included
    # here so two packages never share a stored key by accident.
    def host_cache_key(value, action:, export_scope:)
      Digest::SHA256.hexdigest(
        ["downloadable-cache-key", action.to_s, export_scope.to_s, value.to_s].join("\0")
      )
    end
  end
end

# frozen_string_literal: true

require "digest"
require "stringio"

module RecordingStudioDownloadable
  DownloadFile = Data.define(:filename, :content_type, :byte_size, :checksum, :identity, :io_factory) do
    def self.from_string(filename:, content:, content_type: "text/plain")
      payload = content.to_s
      digest = Digest::SHA256.hexdigest(payload)

      new(
        filename: filename,
        content_type: content_type,
        byte_size: payload.bytesize,
        checksum: Digest::SHA256.base64digest(payload),
        identity: "generated:#{filename}:#{digest}",
        io_factory: lambda do |&block|
          io = StringIO.new(payload)
          block ? block.call(io) : io
        end
      )
    end

    def self.from_blob(blob, filename: nil)
      raise ArgumentError, "blob is required" if blob.nil?

      name = filename.nil? || filename.to_s.empty? ? blob.filename.to_s : filename.to_s
      new(
        filename: name,
        content_type: blob.content_type,
        byte_size: blob.byte_size,
        checksum: blob.checksum,
        identity: "active-storage:#{blob.id}",
        io_factory: lambda do |&block|
          raise SourceMissingError, "Missing blob for #{blob.id}" unless blob_present?(blob)

          blob.open(&block)
        end
      )
    end

    def self.blob_present?(blob)
      blob.respond_to?(:service) ? blob.service.exist?(blob.key) : true
    rescue StandardError
      false
    end
    private_class_method :blob_present?

    def with_io(&)
      result = io_factory.call(&)
      return result if block_given?

      result
    end
  end
end

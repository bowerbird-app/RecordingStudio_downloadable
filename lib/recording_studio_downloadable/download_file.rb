# frozen_string_literal: true

module RecordingStudioDownloadable
  DownloadFile = Data.define(:filename, :content_type, :byte_size, :checksum, :identity, :io_factory) do
    def with_io(&)
      result = io_factory.call(&)
      return result if block_given?

      result
    end
  end
end

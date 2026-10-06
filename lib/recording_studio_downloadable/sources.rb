# frozen_string_literal: true

require_relative "sources/attachments"
require_relative "sources/manifest"

module RecordingStudioDownloadable
  module Sources
    COLLECTORS = {
      attachments: Attachments,
      manifest: Manifest
    }.freeze

    module_function

    def collect(source, recording)
      collector = COLLECTORS[source.to_sym]
      unless collector
        raise UnsupportedOptionError, "Unsupported Downloadable source: #{source.inspect}"
      end

      collector.call(recording)
    end
  end
end

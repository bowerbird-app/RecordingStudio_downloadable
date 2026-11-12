# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    module PackagePayload
      module_function

      def for(recording, package)
        {
          state: package&.state || "missing",
          ready: recording.downloadable_ready?,
          stale: recording.downloadable_stale?,
          failed: package&.failed? || false,
          failure_message: package&.failure_message
        }
      end
    end
  end
end

# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    class PackageStatus
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = GrantScope.recording_in_grant!(context)
        GrantScope.authorize_downloadable!(context, recording)
        PackagePayload.for(recording, recording.downloadable_package)
      end

      private

      attr_reader :context
    end
  end
end

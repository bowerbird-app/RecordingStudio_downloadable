# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    class DownloadRecording
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = GrantScope.recording_in_grant!(context)
        GrantScope.authorize_download!(context, recording)
        package = GrantScope.map_authorization! do
          RecordingStudioDownloadable.download!(
            recording: recording,
            actor: context.access_grant.actor
          )
        end
        PackagePayload.for(recording, package)
      end

      private

      attr_reader :context
    end
  end
end

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
        RecordingStudioDownloadable::RequestMemo.with_request_memo do
          recording = GrantScope.recording_in_grant!(context)
          GrantScope.authorize_downloadable!(context, recording)
          refuse_blocked_gate!(recording)
          throttle!(recording)
          raise RecordingStudioApi::NotFoundError if recording.downloadable_empty?

          generate_package!(recording)
          PackagePayload.for(recording, recording.downloadable_package)
        end
      end

      private

      attr_reader :context

      def throttle!(recording)
        RateLimiter.throttle!(
          action: recording.downloadable_action,
          ip: nil,
          actor: context.access_grant.actor,
          recording: recording
        )
      end

      def generate_package!(recording)
        return if recording.downloadable_ready?

        recording.downloadable_generate!(
          action: recording.downloadable_action,
          export_scope: recording.downloadable_export_scope
        )
      end

      def refuse_blocked_gate!(recording)
        gate = DownloadGate.for_action(recording.downloadable_action)
        return unless DownloadGate.blocking?(
          gate,
          recording: recording,
          actor: context.access_grant.actor,
          request: nil
        )

        raise RecordingStudioApi::AuthorizationError, Copy.t("errors.not_authorized", default: Copy::NOT_AUTHORIZED)
      end
    end
  end
end

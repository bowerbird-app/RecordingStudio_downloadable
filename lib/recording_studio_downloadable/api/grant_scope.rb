# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    module GrantScope
      module_function

      def recording_in_grant!(context)
        recording = context.recording
        found = context.access_grant.accessible_recordings.find_by(id: recording.id)
        return found if found

        raise RecordingStudioApi::NotFoundError, "Recording was not found in this API scope"
      end

      def authorize_download!(context, recording)
        options = capability_options_for(recording)
        role = Authorization.required_role_for(recording.downloadable_action, capability_options: options)
        context.access_grant.authorize!(recording: recording, role: role)
      end

      def authorize_downloadable!(context, recording)
        options = capability_options_for(recording)
        authorize_download!(context, recording)
        Authorization.authorize!(
          action: recording.downloadable_action,
          actor: context.access_grant.actor,
          recording: recording,
          capability_options: options
        )
      rescue Authorization::NotAuthorizedError => e
        raise RecordingStudioApi::AuthorizationError, e.message
      end

      def capability_options_for(recording)
        RecordingStudio.capability_options(:downloadable, for: recording.recordable_type) || {}
      end
    end
  end
end

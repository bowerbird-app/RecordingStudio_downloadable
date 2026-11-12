# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    module GrantScope
      module_function

      def recording_in_grant!(context)
        recording = context.recording
        found = context.access_grant.accessible_recordings.find_by(id: recording.id)
        return found if found

        raise_not_found!("Recording was not found in this API scope")
      end

      def authorize_download!(context, recording)
        role = Authorization.required_role_for(recording.downloadable_action)
        context.access_grant.authorize!(recording: recording, role: role)
      end

      def raise_forbidden!(message)
        raise RecordingStudioApi::AuthorizationError, message if defined?(RecordingStudioApi::AuthorizationError)

        raise Authorization::NotAuthorizedError, message
      end

      def raise_not_found!(message)
        raise RecordingStudioApi::NotFoundError, message if defined?(RecordingStudioApi::NotFoundError)

        raise ActiveRecord::RecordNotFound, message
      end

      def map_authorization!
        yield
      rescue Authorization::NotAuthorizedError => e
        raise_forbidden!(e.message)
      end
    end
  end
end

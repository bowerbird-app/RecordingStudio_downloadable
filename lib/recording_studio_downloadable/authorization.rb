# frozen_string_literal: true

module RecordingStudioDownloadable
  module Authorization
    class NotAuthorizedError < RecordingStudioDownloadable::Error; end
    class CapabilityNotEnabledError < NotAuthorizedError; end

    class << self
      def authorize!(action:, actor:, recording:, capability_options: nil)
        assert_downloadable_enabled!(recording: recording, capability_options: capability_options)
        return true if allowed?(
          action: action,
          actor: actor,
          recording: recording,
          capability_options: capability_options
        )

        raise NotAuthorizedError,
              "Not authorized to #{action} packages for #{recording&.recordable_type || recording.class.name}"
      end

      def allowed?(action:, actor:, recording:, capability_options: nil)
        return false unless downloadable_enabled?(recording: recording, capability_options: capability_options)

        role = required_role_for(action, capability_options: capability_options)
        return false if role.blank?

        adapter = authorization_adapter(capability_options)
        if adapter.respond_to?(:call)
          return !!adapter.call(action: action, actor: actor, recording: recording, role: role)
        end

        return false unless defined?(RecordingStudioAccessible::Authorization)

        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
      end

      def authorization_adapter(capability_options)
        capability_options.to_h[:authorize_with] || RecordingStudioDownloadable.configuration.authorize_with
      end

      def required_role_for(action, capability_options: nil)
        roles = RecordingStudioDownloadable.configuration.auth_roles.merge(
          capability_options.to_h[:auth_roles].to_h
        )
        RecordingStudioDownloadable.configuration.normalize_role(roles[action.to_sym])
      end

      def downloadable_enabled?(recording:, capability_options: nil)
        owner_type = owner_type_for(recording)
        return false if owner_type.blank?

        if defined?(RecordingStudio) &&
           RecordingStudio.respond_to?(:configuration) &&
           RecordingStudio.configuration.respond_to?(:capability_enabled?)
          RecordingStudio.configuration.capability_enabled?(:downloadable, for_type: owner_type)
        else
          capability_options.present?
        end
      end

      def assert_downloadable_enabled!(recording:, capability_options: nil)
        return if downloadable_enabled?(recording: recording, capability_options: capability_options)

        raise CapabilityNotEnabledError,
              "Downloadable capability is not enabled for #{owner_type_for(recording) || recording.class.name}"
      end

      def owner_recording_for(recording)
        recording
      end

      def owner_type_for(recording)
        owner_recording_for(recording)&.recordable_type
      end
    end
  end
end

# frozen_string_literal: true

module RecordingStudioDownloadable
  module Authorization
    class NotAuthorizedError < RecordingStudioDownloadable::Error; end
    class CapabilityNotEnabledError < NotAuthorizedError; end

    class << self
      def authorize!(action:, actor:, recording:, capability_options: nil, controller: nil)
        assert_downloadable_enabled!(recording: recording, capability_options: capability_options)
        return true if allowed?(
          action: action,
          actor: actor,
          recording: recording,
          capability_options: capability_options,
          controller: controller
        )

        raise NotAuthorizedError, Copy.t("errors.not_authorized")
      end

      def allowed?(action:, actor:, recording:, capability_options: nil, controller: nil)
        return false unless downloadable_enabled?(recording: recording, capability_options: capability_options)

        return false unless audience_allows?(
          action: action,
          actor: actor,
          recording: recording,
          capability_options: capability_options,
          controller: controller
        )

        domain_available?(actor: actor, recording: recording, action: action)
      rescue StandardError
        false
      end

      def granted_to_generate?(actor:, recording:, action:, capability_options: nil)
        return false if actor.blank?
        return false unless downloadable_enabled?(recording: recording, capability_options: capability_options)

        if action_audiences_configured?(action)
          roles = RecordingStudioAccessible.granted_roles_for(action.to_sym)
          return false if roles.blank?

          return RecordingStudioAccessible.authorized_for_any_role?(
            actor: actor,
            recording: recording,
            roles: roles
          )
        end

        role = required_role_for(action, capability_options: capability_options)
        return false if role.blank?
        return false unless defined?(RecordingStudioAccessible::Authorization)

        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
      rescue StandardError
        false
      end

      def authorization_adapter(capability_options)
        capability_options.to_h[:authorize_with] || RecordingStudioDownloadable.configuration.authorize_with
      end

      def required_role_for(action, capability_options: nil)
        roles = RecordingStudioDownloadable.configuration.auth_roles.merge(
          capability_options.to_h[:auth_roles].to_h
        )
        RecordingStudioDownloadable.configuration.normalize_role(
          roles[action.to_sym] || roles[:download]
        )
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

        raise CapabilityNotEnabledError, Copy.t("errors.capability_disabled")
      end

      def owner_recording_for(recording)
        recording
      end

      def owner_type_for(recording)
        owner_recording_for(recording)&.recordable_type
      end

      def action_audiences_configured?(action)
        return false unless defined?(RecordingStudioAccessible)
        return false unless RecordingStudioAccessible.respond_to?(:configuration)

        audiences = RecordingStudioAccessible.configuration.action_audiences
        audiences.respond_to?(:configured?) && audiences.configured?(action.to_sym)
      rescue StandardError
        false
      end

      private

      def audience_allows?(action:, actor:, recording:, capability_options:, controller:)
        adapter = authorization_adapter(capability_options)
        if adapter.respond_to?(:call)
          role = required_role_for(action, capability_options: capability_options)
          return !!adapter.call(action: action, actor: actor, recording: recording, role: role)
        end

        accessible_allows?(action: action, actor: actor, recording: recording, controller: controller)
      end

      def accessible_allows?(action:, actor:, recording:, controller:)
        return false unless defined?(RecordingStudioAccessible)

        if uses_authorized_action?(action)
          return RecordingStudioAccessible.authorized_action?(
            actor: actor,
            action: action.to_sym,
            recording: recording,
            controller: controller
          )
        end

        role = required_role_for(action)
        return false if role.blank?
        return false unless defined?(RecordingStudioAccessible::Authorization)

        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
      end

      def uses_authorized_action?(action)
        return false unless defined?(RecordingStudioAccessible)
        return true if action_audiences_configured?(action)

        RecordingStudioAccessible.respond_to?(:action_defined?) &&
          RecordingStudioAccessible.action_defined?(action.to_sym)
      rescue StandardError
        false
      end

      def domain_available?(actor:, recording:, action:)
        hook_target = domain_hook_target(recording)
        return true unless hook_target

        !!hook_target.downloadable_available_for?(actor: actor, action: action)
      rescue StandardError
        false
      end

      def domain_hook_target(recording)
        if recording.respond_to?(:recordable)
          recordable = recording.recordable
          return recordable if recordable.respond_to?(:downloadable_available_for?)
        end

        recording if recording.respond_to?(:downloadable_available_for?)
      rescue StandardError
        recording if recording.respond_to?(:downloadable_available_for?)
      end
    end
  end
end

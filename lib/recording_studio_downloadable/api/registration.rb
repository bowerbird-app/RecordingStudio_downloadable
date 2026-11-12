# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    module Registration
      class << self
        def register!
          return unless defined?(RecordingStudioApi)

          RecordingStudioApi.configuration.each_api do |api_definition|
            ACTIONS.each_key { |name| register_action(name, api_definition.name) }
          end
        end

        private

        def register_action(name, api_name)
          existing = RecordingStudioApi.capability_action(name, api: api_name)
          if existing
            spec = ACTIONS.fetch(name)
            return if existing.capability == :downloadable && existing.handler == spec.fetch(:handler)

            raise RecordingStudioApi::ConfigurationError,
                  "API action #{name} is already registered on #{api_name}"
          end

          RecordingStudioApi.register_capability_action(name, **action_options(name, api_name))
        end

        def action_options(name, api_name)
          spec = ACTIONS.fetch(name)
          {
            api: api_name, capability: :downloadable, version: ACTION_VERSION,
            http_verb: spec.fetch(:http_verb), scope: :member, required_role: Api.download_role,
            handler: spec.fetch(:handler), serializer: ->(result, *) { result },
            input_contract: { reject_unknown: false, fields: {} }, openapi: openapi_for(spec)
          }
        end

        def openapi_for(spec)
          { summary: spec.fetch(:summary), description: spec.fetch(:description) }
        end
      end
    end
  end
end

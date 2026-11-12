# frozen_string_literal: true

module RecordingStudioDownloadable
  module Api
    module Registration
      class << self
        def register!
          return unless recording_studio_api_available?

          if named_api_registration_supported?
            RecordingStudioApi.configuration.each_api do |api_definition|
              register_actions_for(api_definition.name)
            end
          else
            register_actions_for(nil)
          end
        end

        private

        def register_actions_for(api_name)
          ACTIONS.each_key { |name| register_action(name, api_name) }
        end

        def register_action(name, api_name)
          return if existing_action(name, api_name)

          options = capability_action_options(name)
          if api_name
            RecordingStudioApi.register_capability_action(name, api: api_name, **options)
          else
            RecordingStudioApi.register_capability_action(name, **options)
          end
        end

        def existing_action(name, api_name)
          if api_name
            RecordingStudioApi.capability_action(name, api: api_name)
          else
            RecordingStudioApi.capability_action(name)
          end
        end

        def named_api_registration_supported?
          RecordingStudioApi.respond_to?(:configuration) &&
            RecordingStudioApi.configuration.respond_to?(:each_api) &&
            action_api_accepts_api?(:capability_action) &&
            action_api_accepts_api?(:register_capability_action)
        end

        def action_api_accepts_api?(method_name)
          RecordingStudioApi.method(method_name).parameters.any? do |type, name|
            type == :keyrest || (name == :api && %i[key keyreq].include?(type))
          end
        end

        def capability_action_options(name)
          spec = ACTIONS.fetch(name)
          action_metadata(spec).merge(
            handler: spec.fetch(:handler),
            serializer: ->(result, *) { result },
            input_contract: empty_input_contract,
            openapi: openapi_for(spec)
          )
        end

        def action_metadata(spec)
          {
            capability: :downloadable,
            version: ACTION_VERSION,
            http_verb: spec.fetch(:http_verb),
            scope: :member,
            required_role: Api.download_role
          }
        end

        def openapi_for(spec)
          { summary: spec.fetch(:summary), description: spec.fetch(:description) }
        end

        def recording_studio_api_available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:capability_action) &&
            RecordingStudioApi.respond_to?(:register_capability_action)
        end

        def empty_input_contract
          definition = { reject_unknown: true, fields: {} }
          return definition unless defined?(RecordingStudioApi::ActionInputContract)

          route_parameter_filtering_contract.new(definition)
        end

        def route_parameter_filtering_contract
          Class.new(RecordingStudioApi::ActionInputContract) do
            define_method(:call) do |raw_params|
              params = raw_params.respond_to?(:to_h) ? raw_params.to_h : raw_params
              if params.respond_to?(:except)
                params = params.except(*RecordingStudioDownloadable::Api::INTERNAL_ROUTE_PARAMETER_KEYS)
              end
              super(params)
            end
          end
        end
      end
    end
  end
end

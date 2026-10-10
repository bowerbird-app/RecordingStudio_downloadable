# frozen_string_literal: true

require "recording_studio_attachable"

module RecordingStudioDownloadable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioDownloadable

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      def register_recording_studio_integration
        return unless defined?(RecordingStudio)

        RecordingStudio.register_capability(
          :downloadable,
          recording_methods: RecordingStudio::Capabilities::Downloadable::RecordingMethods,
          source: "recording_studio_downloadable"
        )
      end

      def skip_inherited_host_callbacks!
        controller = RecordingStudioDownloadable::ApplicationController
        return unless controller.respond_to?(:skip_before_action)

        Array(RecordingStudioDownloadable.configuration.skip_host_before_actions).each do |callback|
          controller.skip_before_action callback, raise: false
        end
      end

      def install_recording_observer!
        return unless defined?(RecordingStudio::Recording)
        return if RecordingStudio::Recording.method_defined?(:recording_studio_downloadable_after_commit)

        RecordingStudio::Recording.class_eval do
          after_commit :recording_studio_downloadable_after_commit, on: %i[create update destroy]

          def recording_studio_downloadable_after_commit
            RecordingStudioDownloadable::Invalidation.after_recording_commit(self)
          end
        end
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioDownloadable.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_downloadable_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_downloadable_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end

      def load_yaml_config(app)
        return unless app.respond_to?(:config_for)

        yaml = begin
          app.config_for(:recording_studio_downloadable)
        rescue StandardError
          nil
        end
        RecordingStudioDownloadable.configuration.merge!(yaml) if yaml.respond_to?(:each)
      rescue StandardError
        nil
      end

      def load_x_config(app)
        return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_downloadable)

        xcfg = app.config.x.recording_studio_downloadable
        if xcfg.respond_to?(:to_h)
          RecordingStudioDownloadable.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value }
          RecordingStudioDownloadable.configuration.merge!(hash) if hash.any?
        end
      rescue StandardError
        nil
      end
    end

    initializer "recording_studio_downloadable.before_initialize",
                before: "recording_studio_downloadable.load_config" do |_app|
      RecordingStudioDownloadable.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_downloadable.load_config" do |app|
      RecordingStudioDownloadable::Engine.send(:load_yaml_config, app)
      RecordingStudioDownloadable::Engine.send(:load_x_config, app)
      RecordingStudioDownloadable.configuration.hooks.run(
        :on_configuration,
        RecordingStudioDownloadable.configuration
      )
    end

    initializer "recording_studio_downloadable.after_initialize",
                after: "recording_studio_downloadable.load_config" do |_app|
      RecordingStudioDownloadable.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_downloadable.register_recording_studio_integration" do |app|
      RecordingStudioDownloadable::Engine.register_recording_studio_integration

      app.config.after_initialize do
        RecordingStudioDownloadable::Engine.register_recording_studio_integration
      end
    end

    initializer "recording_studio_downloadable.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/javascript")
    end

    initializer "recording_studio_downloadable.action_view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioDownloadable::ApplicationHelper
      end
    end

    initializer "recording_studio_downloadable.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioDownloadable::Engine.apply_model_extensions(model)
        end
      end
    end

    initializer "recording_studio_downloadable.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioDownloadable::Engine.apply_controller_extensions(controller)
        end
      end
    end

    initializer "recording_studio_downloadable.skip_host_auth" do
      config.to_prepare do
        RecordingStudioDownloadable::Engine.skip_inherited_host_callbacks!
      end
    end

    initializer "recording_studio_downloadable.observe_recordings" do
      config.to_prepare do
        RecordingStudioDownloadable::Engine.install_recording_observer!
      end
    end
  end
end

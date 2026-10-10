# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Downloadable
      SUPPORTED_SOURCES = %i[attachments manifest].freeze
      SUPPORTED_FORMATS = %i[zip].freeze
      DEFAULTS = { source: :attachments, format: :zip }.freeze
      OPTIONAL_KEYS = %i[action export_scope].freeze
      ALLOWED_KEYS = (DEFAULTS.keys + OPTIONAL_KEYS).freeze
      DEFAULT_EXPORT_SCOPE = :public

      def self.to(source: DEFAULTS[:source], format: DEFAULTS[:format], action: nil, export_scope: nil, **unknown)
        options = DEFAULTS.merge(source: source, format: format)
        options[:action] = action if action
        options[:export_scope] = export_scope if export_scope
        validate_options!(options.merge(unknown))
        RecordingStudio::Capabilities.include_for(:downloadable, **options.compact)
      end

      def self.default_action_for(recordable_type)
        return :"recordings.download" if recordable_type.to_s.strip.empty?

        key = recordable_type.to_s.underscore.tr("/", "_").pluralize
        :"#{key}.download"
      end

      def self.normalize_export_scope(value)
        scope = value.presence || DEFAULT_EXPORT_SCOPE
        scope.to_s.to_sym
      end

      def self.validate_options!(options)
        unknown = options.keys - ALLOWED_KEYS
        unless unknown.empty?
          raise ArgumentError,
                "unknown Downloadable option(s): #{unknown.map { |key| "#{key}:" }.join(', ')}. " \
                "Use source:, format:, action:, and export_scope:."
        end

        source = options.fetch(:source).to_sym
        format = options.fetch(:format).to_sym

        unless SUPPORTED_SOURCES.include?(source)
          raise RecordingStudioDownloadable::UnsupportedOptionError,
                "Unsupported Downloadable source: #{source.inspect}. " \
                "V1 supports #{SUPPORTED_SOURCES.join(', ')}."
        end

        return if SUPPORTED_FORMATS.include?(format)

        raise RecordingStudioDownloadable::UnsupportedOptionError,
              "Unsupported Downloadable format: #{format.inspect}. " \
              "V1 supports #{SUPPORTED_FORMATS.join(', ')}."
      end
      private_class_method :validate_options!

      module RecordingMethods
        include RecordingStudio::Capability if defined?(RecordingStudio::Capability)

        def downloadable?
          return false unless defined?(RecordingStudio)

          RecordingStudio.capability_enabled?(:downloadable, for: recordable_type)
        end

        def downloadable_action
          configured = downloadable_options[:action]
          return configured.to_sym if configured.present?

          RecordingStudio::Capabilities::Downloadable.default_action_for(recordable_type)
        end

        def downloadable_export_scope
          RecordingStudio::Capabilities::Downloadable.normalize_export_scope(
            downloadable_options[:export_scope]
          )
        end

        def downloadable_files
          assert_downloadable_capability!
          RecordingStudioDownloadable::Services::CollectFiles.call(recording: self).value!
        end

        def downloadable_empty?
          downloadable_files.empty?
        end

        def downloadable_package(action: downloadable_action, export_scope: downloadable_export_scope)
          assert_downloadable_capability!
          RecordingStudioDownloadable::Package.find_by(
            recording_id: id,
            action: action.to_s,
            export_scope: export_scope.to_s,
            format: downloadable_format.to_s
          )
        end

        def downloadable_ready?(action: downloadable_action, export_scope: downloadable_export_scope)
          package = downloadable_package(action: action, export_scope: export_scope)
          package.present? && package.ready? && !stale_package?(package, action: action, export_scope: export_scope) &&
            package.archive.attached?
        end

        def downloadable_stale?(action: downloadable_action, export_scope: downloadable_export_scope)
          package = downloadable_package(action: action, export_scope: export_scope)
          package.present? && package.ready? && stale_package?(package, action: action, export_scope: export_scope)
        end

        def downloadable_generate!(action: downloadable_action, export_scope: downloadable_export_scope, wait: nil,
                                   force: true)
          assert_downloadable_capability!
          RecordingStudioDownloadable::Services::EnqueueGeneration.call(
            recording: self,
            action: action,
            export_scope: export_scope,
            wait: wait,
            force: force
          ).value
        end

        def downloadable_invalidate!(immediate: false, enqueue: true, action: downloadable_action,
                                     export_scope: downloadable_export_scope)
          assert_downloadable_capability!
          RecordingStudioDownloadable::Invalidation.invalidate!(
            recording: self,
            action: action,
            export_scope: export_scope,
            immediate: immediate,
            enqueue: enqueue
          )
        end

        def downloadable_download_path
          assert_downloadable_capability!
          RecordingStudioDownloadable::Engine.routes.url_helpers.recording_package_path(self)
        end

        def downloadable_source_fingerprint(action: downloadable_action, export_scope: downloadable_export_scope)
          RecordingStudioDownloadable::Fingerprint.call(
            downloadable_files,
            action: action,
            export_scope: export_scope
          )
        end

        def downloadable_source
          downloadable_options.fetch(:source, :attachments).to_sym
        end

        def downloadable_format
          downloadable_options.fetch(:format, :zip).to_sym
        end

        def downloadable_current_fingerprint_matches?(package, action: downloadable_action,
                                                      export_scope: downloadable_export_scope)
          package.present? &&
            package.action.to_s == action.to_s &&
            package.export_scope.to_s == export_scope.to_s &&
            package.source_fingerprint == downloadable_source_fingerprint(action: action, export_scope: export_scope)
        end

        private

        def assert_downloadable_capability!
          return unless respond_to?(:assert_capability!, true)

          assert_capability!(:downloadable)
        end

        def downloadable_options
          return {} unless defined?(RecordingStudio)

          RecordingStudio.capability_options(:downloadable, for: recordable_type) || {}
        end

        def stale_package?(package, action:, export_scope:)
          !downloadable_current_fingerprint_matches?(package, action: action, export_scope: export_scope)
        end
      end
    end
  end
end

if defined?(RecordingStudio) && RecordingStudio.respond_to?(:register_capability)
  RecordingStudio.register_capability(
    :downloadable,
    recording_methods: RecordingStudio::Capabilities::Downloadable::RecordingMethods,
    source: "recording_studio_downloadable"
  )
end

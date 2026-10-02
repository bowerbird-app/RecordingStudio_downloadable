# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Downloadable
      SUPPORTED_SOURCES = %i[attachments].freeze
      SUPPORTED_FORMATS = %i[zip].freeze
      DEFAULTS = { source: :attachments, format: :zip }.freeze

      def self.to(source: DEFAULTS[:source], format: DEFAULTS[:format], **unknown)
        options = DEFAULTS.merge(source: source, format: format)
        validate_options!(options.merge(unknown))
        RecordingStudio::Capabilities.include_for(:downloadable, **options)
      end

      def self.validate_options!(options)
        unknown = options.keys - DEFAULTS.keys
        unless unknown.empty?
          raise ArgumentError,
                "unknown Downloadable option(s): #{unknown.map { |key| "#{key}:" }.join(', ')}. " \
                "Use source: and format:."
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

        def downloadable_files
          assert_downloadable_capability!
          RecordingStudioDownloadable::Services::CollectFiles.call(recording: self).value!
        end

        def downloadable_empty?
          downloadable_files.empty?
        end

        def downloadable_package
          assert_downloadable_capability!
          RecordingStudioDownloadable::Package.find_by(
            recording_id: id,
            format: downloadable_format
          )
        end

        def downloadable_ready?
          package = downloadable_package
          package.present? && package.ready? && !stale_package?(package) && package.archive.attached?
        end

        def downloadable_stale?
          package = downloadable_package
          package.present? && package.ready? && stale_package?(package)
        end

        def downloadable_generate!
          assert_downloadable_capability!
          RecordingStudioDownloadable::Services::EnqueueGeneration.call(recording: self).value
        end

        def downloadable_download_path
          assert_downloadable_capability!
          RecordingStudioDownloadable::Engine.routes.url_helpers.recording_package_path(self)
        end

        def downloadable_source_fingerprint
          RecordingStudioDownloadable::Fingerprint.call(downloadable_files)
        end

        def downloadable_source
          downloadable_options.fetch(:source, :attachments).to_sym
        end

        def downloadable_format
          downloadable_options.fetch(:format, :zip).to_sym
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

        def stale_package?(package)
          package.source_fingerprint != downloadable_source_fingerprint
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

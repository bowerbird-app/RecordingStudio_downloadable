# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class GeneratePackage < BaseService
      def initialize(package:)
        @package = package
      end

      private

      attr_reader :package

      def perform
        package.with_lock do
          recording = package.recording
          files = CollectFiles.call(recording: recording).value!

          if files.empty?
            package.archive.purge if package.archive.attached?
            package.mark_failed!("Source set is empty")
            return failure(EmptySourceError.new("Source set is empty"))
          end

          fingerprint = Fingerprint.call(files)
          if package.ready? && !package.stale_for?(fingerprint) && package.archive.attached?
            return success(package)
          end

          package.mark_processing!
          attach_archive!(files, fingerprint)
          success(package.reload)
        end
      rescue EmptySourceError, SourceMissingError, UnsupportedOptionError, GenerationError => error
        fail_package!(error)
        failure(error)
      rescue StandardError => error
        fail_package!(error)
        failure(GenerationError.new(error.message))
      end

      def attach_archive!(files, fingerprint)
        ZipBuilder.new(files).write do |io|
          package.archive.attach(
            io: io,
            filename: archive_filename,
            content_type: "application/zip"
          )
        end

        raise GenerationError, "Failed to store archive" unless package.archive.attached?

        package.mark_ready!(fingerprint: fingerprint)
      end

      def archive_filename
        recordable = package.recording.recordable
        base = recordable.try(:name).presence || recordable.try(:title).presence || package.recording_id
        "#{Filename.sanitize(base)}.zip"
      end

      def fail_package!(error)
        package.mark_failed!(error.message)
      rescue StandardError
        nil
      end
    end
  end
end

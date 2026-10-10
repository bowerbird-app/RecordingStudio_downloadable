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
        recording = package.recording
        files = CollectFiles.call(recording: recording).value!

        if files.empty?
          package.with_lock do
            package.archive.purge if package.archive.attached?
            package.mark_failed!(Copy.t("notices.empty"))
          end
          return failure(EmptySourceError.new(Copy.t("notices.empty")))
        end

        fingerprint = recording.downloadable_source_fingerprint(
          action: package.action,
          export_scope: package.export_scope
        )
        package.with_lock do
          return success(package) if package.ready? && !package.stale_for?(fingerprint) && package.archive.attached?
        end

        blob = upload_archive!(files)
        assert_archive_size!(blob)
        package.with_lock do
          package.mark_processing!
          package.archive.purge if package.archive.attached?
          package.archive.attach(blob)
          raise GenerationError, "Failed to store archive" unless package.archive.attached?

          package.mark_ready!(fingerprint: fingerprint)
          success(package.reload)
        end
      rescue EmptySourceError, SourceMissingError, UnsupportedOptionError, GenerationError, ArchiveTooLargeError => e
        fail_package!(e)
        failure(e)
      rescue StandardError => e
        fail_package!(e)
        failure(GenerationError.new(e.message))
      end

      def upload_archive!(files)
        ZipBuilder.new(files).write do |io|
          io.rewind
          ActiveStorage::Blob.create_and_upload!(
            io: io,
            filename: archive_filename,
            content_type: "application/zip"
          )
        end
      end

      def assert_archive_size!(blob)
        max = RecordingStudioDownloadable.configuration.max_zip_bytes
        return if max.blank? || max.to_i <= 0
        return if blob.byte_size <= max.to_i

        blob.purge
        raise ArchiveTooLargeError, Copy.t("errors.archive_too_large")
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

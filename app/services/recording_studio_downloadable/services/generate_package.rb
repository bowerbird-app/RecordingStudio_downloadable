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
        key_before = cache_key_for(recording, fresh: true)
        return success(package) if current_package?(key_before)

        package.mark_processing!
        files = CollectFiles.call(recording: recording).value!

        if files.empty?
          package.with_lock do
            package.archive.purge if package.archive.attached?
            package.mark_failed!(Copy.t("notices.empty", default: Copy::EMPTY_NOTICE))
          end
          return failure(EmptySourceError.new(Copy.t("notices.empty", default: Copy::EMPTY_NOTICE)))
        end

        blob = upload_archive!(files)
        assert_archive_size!(blob)
        key_after = cache_key_for(recording, fresh: true)
        finish_package!(blob, key_before, key_after)
      rescue EmptySourceError, SourceMissingError, UnsupportedOptionError, GenerationError, ArchiveTooLargeError => e
        fail_package!(e)
        failure(e)
      rescue StandardError => e
        fail_package!(e)
        failure(GenerationError.new(e.message))
      end

      def cache_key_for(recording, fresh:)
        recording.downloadable_cache_key(
          action: package.action,
          export_scope: package.export_scope,
          fresh: fresh
        )
      end

      def current_package?(key)
        package.ready? && package.archive.attached? && !package.stale_for?(key)
      end

      # The key is read before the file list and again after the zip exists.
      # A change in between means the zip does not match the current key, so
      # the package stays unready and another build is queued.
      def finish_package!(blob, key_before, key_after)
        if key_before != key_after
          blob.purge
          package.with_lock do
            package.update!(state: "pending", source_fingerprint: key_before, failure_message: nil)
          end
          GeneratePackageJob.perform_later(package.id)
          return success(package)
        end

        package.with_lock do
          if current_package?(key_before)
            blob.purge
            return success(package)
          end

          package.mark_processing!
          package.archive.purge if package.archive.attached?
          package.archive.attach(blob)
          raise GenerationError, "Failed to store archive" unless package.archive.attached?

          package.mark_ready!(fingerprint: key_before)
          success(package.reload)
        end
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
        raise ArchiveTooLargeError, Copy.t("errors.archive_too_large", default: Copy::ARCHIVE_TOO_LARGE)
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

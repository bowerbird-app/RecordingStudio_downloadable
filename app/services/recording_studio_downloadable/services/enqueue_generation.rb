# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class EnqueueGeneration < BaseService
      def initialize(recording:)
        @recording = recording
      end

      private

      attr_reader :recording

      def perform
        files = CollectFiles.call(recording: recording).value!
        return success(nil) if files.empty?

        fingerprint = Fingerprint.call(files)
        package = nil

        Package.transaction do
          package = Package.lock.find_or_initialize_by(
            recording_id: recording.id,
            format: recording.downloadable_format.to_s
          )

          if reusable?(package, fingerprint)
            next
          end

          package.assign_attributes(
            state: "pending",
            source_fingerprint: fingerprint,
            failure_message: nil
          )
          package.save!
          GeneratePackageJob.perform_later(package.id)
        end

        success(package)
      end

      def reusable?(package, fingerprint)
        return false unless package.persisted?
        return false if package.stale_for?(fingerprint)

        (package.ready? && package.archive.attached?) || package.processing? || package.pending?
      end
    end
  end
end

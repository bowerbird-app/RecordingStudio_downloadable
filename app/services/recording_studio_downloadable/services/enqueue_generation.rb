# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class EnqueueGeneration < BaseService
      def initialize(recording:, action: nil, export_scope: nil, wait: nil, force: true)
        @recording = recording
        @action = (action || recording.downloadable_action).to_sym
        @export_scope = RecordingStudio::Capabilities::Downloadable.normalize_export_scope(
          export_scope || recording.downloadable_export_scope
        )
        @wait = wait
        @force = force
      end

      private

      attr_reader :recording, :action, :export_scope, :wait, :force

      def perform
        files = CollectFiles.call(recording: recording).value!
        return success(nil) if files.empty?

        fingerprint = Fingerprint.call(files, action: action, export_scope: export_scope)
        package = nil

        Package.transaction do
          package = Package.lock.find_or_initialize_by(
            recording_id: recording.id,
            action: action.to_s,
            export_scope: export_scope.to_s,
            format: recording.downloadable_format.to_s
          )

          next if reusable?(package, fingerprint)

          RateLimiter.assert_concurrent_capacity!(action: action, package: package)

          package.assign_attributes(
            state: "pending",
            source_fingerprint: fingerprint,
            failure_message: nil
          )
          package.save!
          enqueue_job!(package)
        end

        success(package)
      end

      def reusable?(package, fingerprint)
        return false unless package.persisted?

        if package.pending? || package.processing?
          package.update!(source_fingerprint: fingerprint) if package.source_fingerprint != fingerprint
          return true
        end

        return false if package.stale_for?(fingerprint)

        package.ready? && package.archive.attached?
      end

      def enqueue_job!(package)
        delay = delay_interval
        if delay&.positive?
          GeneratePackageJob.set(wait: delay).perform_later(package.id)
        else
          GeneratePackageJob.perform_later(package.id)
        end
      end

      def delay_interval
        return if force
        return wait if wait&.positive?

        RecordingStudioDownloadable.configuration.debounce_wait
      end
    end
  end
end

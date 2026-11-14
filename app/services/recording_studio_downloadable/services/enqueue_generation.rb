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
        return success(nil) if recording.downloadable_empty?

        key = recording.downloadable_cache_key(action: action, export_scope: export_scope)
        package = claim_and_enqueue!(key)
        ActiveRecord::Base.connection.clear_query_cache
        recording.clear_downloadable_package_memo!
        success(package)
      end

      def claim_and_enqueue!(key)
        Package.transaction do
          package = locked_package
          next create_pending!(key) if package.nil?
          next package if leave_in_place?(package, key)
          next package unless claim_for_build!(package, key) == 1

          package.reload
          enqueue_job!(package)
          package
        end
      rescue ActiveRecord::RecordNotUnique
        find_package
      end

      def leave_in_place?(package, key)
        return true if in_flight?(package)

        current_package?(package, key)
      end

      def in_flight?(package)
        package.pending? || package.processing?
      end

      def current_package?(package, key)
        package.ready? && package.archive.attached? && !package.stale_for?(key)
      end

      def create_pending!(key)
        RateLimiter.assert_concurrent_capacity!(action: action, package: nil)
        package = Package.create!(package_identity.merge(
                                    state: "pending",
                                    source_fingerprint: key,
                                    failure_message: nil
                                  ))
        enqueue_job!(package)
        package
      end

      def claim_for_build!(package, key)
        RateLimiter.assert_concurrent_capacity!(action: action, package: package)
        Package.where(id: package.id).where.not(state: %w[pending processing]).update_all(
          state: "pending",
          source_fingerprint: key,
          failure_message: nil,
          updated_at: Time.current
        )
      end

      def locked_package
        Package.lock.find_by(package_identity)
      end

      def find_package
        Package.find_by(package_identity)
      end

      def package_identity
        {
          recording_id: recording.id,
          action: action.to_s,
          export_scope: export_scope.to_s,
          format: recording.downloadable_format.to_s
        }
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

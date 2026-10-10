# frozen_string_literal: true

module RecordingStudioDownloadable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    protect_from_forgery with: :exception

    rescue_from RecordingStudioDownloadable::Authorization::NotAuthorizedError, with: :handle_not_authorized
    rescue_from RecordingStudioDownloadable::RateLimitedError, with: :handle_rate_limited
    rescue_from RecordingStudioDownloadable::ConcurrentBuildLimitError, with: :handle_rate_limited
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveStorage::FileNotFoundError, with: :handle_record_not_found

    private

    def current_downloadable_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor) && Current.actor
      return current_user if respond_to?(:current_user, true)

      nil
    end

    def find_recording(id = params[:recording_id])
      scope = RecordingStudio::Recording
      scope = scope.unscoped if scope.respond_to?(:unscoped)
      recording = scope.find(id)
      raise ActiveRecord::RecordNotFound if recording.respond_to?(:trashed_at) && recording.trashed_at.present?

      recording
    end

    def authorize_download!(recording)
      RecordingStudioDownloadable::Authorization.authorize!(
        action: downloadable_action_for(recording),
        actor: current_downloadable_actor,
        recording: recording,
        capability_options: capability_options_for(recording),
        controller: self
      )
    end

    def downloadable_action_for(recording)
      recording.downloadable_action
    end

    def downloadable_export_scope_for(recording)
      recording.downloadable_export_scope
    end

    def capability_options_for(recording)
      return {} unless defined?(RecordingStudio)

      RecordingStudio.capability_options(:downloadable, for: recording.recordable_type) || {}
    end

    def throttle_download!(recording)
      RateLimiter.throttle!(
        action: downloadable_action_for(recording),
        ip: request.remote_ip,
        actor: current_downloadable_actor,
        recording: recording
      )
    end

    def handle_not_authorized(_exception)
      respond_to do |format|
        format.html { head :forbidden }
        format.any { head :forbidden }
      end
    end

    def handle_rate_limited(_exception)
      respond_to do |format|
        format.html { head :too_many_requests }
        format.any { head :too_many_requests }
      end
    end

    def handle_record_not_found
      respond_to do |format|
        format.html { head :not_found }
        format.any { head :not_found }
      end
    end
  end
end

# frozen_string_literal: true

module RecordingStudioDownloadable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    protect_from_forgery with: :exception

    rescue_from RecordingStudioDownloadable::Authorization::NotAuthorizedError, with: :handle_not_authorized
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    private

    def current_downloadable_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)
      return current_user if respond_to?(:current_user, true)

      nil
    end

    def find_recording(id = params[:recording_id])
      RecordingStudio::Recording.find(id)
    end

    def authorize_download!(recording)
      RecordingStudioDownloadable::Authorization.authorize!(
        action: :download,
        actor: current_downloadable_actor,
        recording: recording,
        capability_options: capability_options_for(recording)
      )
    end

    def capability_options_for(recording)
      return {} unless defined?(RecordingStudio)

      RecordingStudio.capability_options(:downloadable, for: recording.recordable_type) || {}
    end

    def handle_not_authorized(exception)
      respond_to do |format|
        format.html { head :forbidden }
        format.any { head :forbidden }
      end
      exception
    end

    def handle_record_not_found
      respond_to do |format|
        format.html { head :not_found }
        format.any { head :not_found }
      end
    end
  end
end

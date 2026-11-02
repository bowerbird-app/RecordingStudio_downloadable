# frozen_string_literal: true

module RecordingStudioDownloadable
  # Optional RecordingStudioAdmin registration. Loaded only when that gem is present.
  module Admin
    SCREEN_KEY = "download_logs"
    SECTION_KEY = "downloads"
    RECORDING_KEY = :recording_studio_downloadable_admin_recording
    HISTORY_SCOPE_KEY = :recording_studio_downloadable_admin_history_scope

    module_function

    def register!
      return unless defined?(::RecordingStudioAdmin)

      require_relative "admin/download_logs_queries"
      require_relative "admin/download_logs_series"
      require_relative "admin/download_logs_screen"
      require_relative "admin/downloads_section"

      RecordingStudioAdmin.register_screen(DownloadLogsScreen)
      RecordingStudioAdmin.register_section(DownloadsSection)
    end

    def recording_id?(context)
      recording_id_from(context).present?
    end

    def recording_for(context)
      recording_id = recording_id_from(context)
      return if recording_id.blank?

      find_recording(recording_id)
    end

    def remember_recording(recording)
      Thread.current[RECORDING_KEY] = recording
    end

    def remembered_recording
      Thread.current[RECORDING_KEY]
    end

    def remember_history_scope(scope)
      Thread.current[HISTORY_SCOPE_KEY] = scope
    end

    def remembered_history_scope
      Thread.current[HISTORY_SCOPE_KEY]
    end

    def recording_id_from(context)
      params = context.respond_to?(:params) ? context.params : nil
      return if params.blank?

      params[:recording_id] || params["recording_id"]
    end

    def find_recording(recording_id)
      return unless defined?(RecordingStudio::Recording)

      scope = RecordingStudio::Recording
      scope = scope.unscoped if scope.respond_to?(:unscoped)
      recording = scope.find_by(id: recording_id)
      return if recording.nil?
      return if recording.respond_to?(:trashed_at) && recording.trashed_at.present?

      recording
    end
  end
end

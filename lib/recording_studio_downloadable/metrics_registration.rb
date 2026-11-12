# frozen_string_literal: true

module RecordingStudioDownloadable
  module MetricsRegistration
    TOTAL_METRIC = "download_logs.total"
    TIMESERIES_METRIC = "download_logs.over_time"

    module_function

    def register!
      return unless defined?(RecordingStudioMetrics)
      return if RecordingStudioMetrics.find(TOTAL_METRIC) && !reloading?

      register_download_log_metrics!
    rescue StandardError => e
      raise unless duplicate_registration?(e)
    end

    def register_download_log_metrics!
      RecordingStudioMetrics.register(
        :download_logs,
        model: DownloadLog,
        blast_radius: :recording,
        api_authorize: method(:api_authorized?)
      ) do
        count :total, title: "Downloads"
        timeseries :over_time, title: "Downloads over time", field: :occurred_at
      end
    end

    def api_authorized?(api_context)
      Authorization.view_logs_allowed?(
        actor: actor_from(api_context),
        recording: recording_from(api_context)
      )
    end

    def actor_from(api_context)
      grant = api_context.respond_to?(:access_grant) ? api_context.access_grant : nil
      return grant.actor if grant.respond_to?(:actor)

      api_context.try(:actor)
    end

    def recording_from(api_context)
      return api_context.access_recording if api_context.respond_to?(:access_recording) && api_context.access_recording

      grant = api_context.respond_to?(:access_grant) ? api_context.access_grant : nil
      grant.respond_to?(:root_recording) ? grant.root_recording : api_context.try(:root_recording)
    end

    def duplicate_registration?(error)
      defined?(RecordingStudioMetrics::Errors::DuplicateRegistration) &&
        error.is_a?(RecordingStudioMetrics::Errors::DuplicateRegistration)
    end

    def context_for(recording:, actor:, relation: nil)
      return unless defined?(RecordingStudioMetrics)
      return if recording.nil?

      # Scope is :root, not :recording. Metrics treats every ActiveRecord model as a
      # recordable (the declaration macro lives on the base class) and then adds
      # `id = recordable_id` for recording scope. That drops every download log.
      # Isolation is the authorized relation, already limited to this recording.
      # Pass `relation` when a screen has already applied its filters.
      RecordingStudioMetrics::Context.new(
        actor: actor,
        system: actor.nil?,
        scope: :root,
        access_recording: recording,
        authorized_relation: relation || DownloadLog.where(recording_id: recording.id)
      )
    end

    def reloading?
      defined?(Rails) && Rails.respond_to?(:application) && Rails.application &&
        Rails.application.config.respond_to?(:cache_classes) &&
        Rails.application.config.cache_classes == false
    end
  end
end

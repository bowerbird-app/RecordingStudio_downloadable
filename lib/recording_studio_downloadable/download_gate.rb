# frozen_string_literal: true

module RecordingStudioDownloadable
  # Host-owned pre-download step. Downloadable never reads the metadata keys.
  module DownloadGate
    class << self
      def for_action(action)
        RecordingStudioDownloadable.configuration.download_gate_for(action)
      end

      def blocking?(gate, recording:, actor:, request:)
        return false if gate.nil? || !gate.respond_to?(:satisfied?)

        !gate.satisfied?(recording: recording, actor: actor, request: request)
      rescue StandardError => e
        report(e)
        true
      end

      def continuation_url(gate, recording:, actor:, request:)
        return if gate.nil? || !gate.respond_to?(:continuation_url)

        gate.continuation_url(recording: recording, actor: actor, request: request)
      rescue StandardError => e
        report(e)
        nil
      end

      def metadata_for(gate, recording:, actor:)
        return {} if gate.nil? || !gate.respond_to?(:metadata_for)

        gate.metadata_for(recording: recording, actor: actor)
      rescue StandardError => e
        report(e)
        {}
      end

      def report(error)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(
            "[RecordingStudioDownloadable] download gate failed: #{error.class}: #{error.message}"
          )
        end
        return unless defined?(Rails.error) && Rails.error.respond_to?(:report)

        Rails.error.report(error, handled: true, source: "recording_studio_downloadable")
      rescue StandardError
        nil
      end
    end
  end
end

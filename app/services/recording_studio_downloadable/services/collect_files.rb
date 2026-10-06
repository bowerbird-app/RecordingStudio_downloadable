# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class CollectFiles < BaseService
      def initialize(recording:)
        @recording = recording
      end

      private

      attr_reader :recording

      def perform
        source = capability_option(:source, :attachments).to_sym
        format = capability_option(:format, :zip).to_sym
        RecordingStudio::Capabilities::Downloadable.send(
          :validate_options!,
          source: source,
          format: format
        )

        success(Sources.collect(source, recording))
      end

      def capability_option(name, default)
        options = RecordingStudio.capability_options(:downloadable, for: recording.recordable_type) || {}
        options.fetch(name, default)
      end
    end
  end
end

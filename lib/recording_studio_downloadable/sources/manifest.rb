# frozen_string_literal: true

module RecordingStudioDownloadable
  module Sources
    class Manifest
      METHOD_NAME = :downloadable_manifest

      def self.call(recording)
        new(recording).call
      end

      def initialize(recording)
        @recording = recording
      end

      def call
        owner = manifest_owner
        entries = owner.public_send(METHOD_NAME)
        if !entries.nil? && !entries.is_a?(Array)
          raise InvalidManifestEntryError,
                "downloadable_manifest must return an Array of DownloadFile objects, got #{entries.class}"
        end

        Array(entries).map.with_index { |entry, index| normalize(entry, index) }
      end

      private

      attr_reader :recording

      def manifest_owner
        recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
        return recordable if recordable.respond_to?(METHOD_NAME)
        return recording if recording.respond_to?(METHOD_NAME)

        target = recordable || recording
        class_name = target.respond_to?(:class) ? target.class.name : target.inspect
        raise ManifestMissingError,
              "Downloadable source: :manifest requires #{class_name}##{METHOD_NAME}. " \
              "It does not fall back to attachments."
      end

      def normalize(entry, index)
        return entry if entry.is_a?(DownloadFile)

        raise InvalidManifestEntryError,
              "Invalid downloadable manifest entry at index #{index}: " \
              "#{entry.class} (expected #{DownloadFile})."
      end
    end
  end
end

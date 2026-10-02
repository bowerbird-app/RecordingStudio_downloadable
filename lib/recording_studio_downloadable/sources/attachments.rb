# frozen_string_literal: true

module RecordingStudioDownloadable
  module Sources
    class Attachments
      ATTACHMENT_TYPE = "RecordingStudioAttachable::Attachment"

      def self.call(recording)
        new(recording).call
      end

      def initialize(recording)
        @recording = recording
      end

      def call
        unless defined?(RecordingStudioAttachable)
          raise RecordingStudioDownloadable::Error,
                "recording_studio_attachable must be loaded to collect source: :attachments"
        end

        attachment_recordings.filter_map { |child| download_file_for(child) }
      end

      private

      attr_reader :recording

      def attachment_recordings
        relation = recording.recordings_query(
          include_children: true,
          type: ATTACHMENT_TYPE,
          parent_id: recording.id
        )
        relation = relation.where(trashed_at: nil) if relation.respond_to?(:where)
        if relation.respond_to?(:includes)
          relation = relation.includes(recordable: { file_attachment: :blob })
        end
        relation.respond_to?(:to_a) ? relation.to_a : Array(relation)
      end

      def download_file_for(child)
        attachment = child.respond_to?(:recordable) ? child.recordable : child
        return if attachment.blank?
        return unless attachment.respond_to?(:file) && attachment.file.attached?

        blob = attachment.file.blob
        return if blob.blank?

        DownloadFile.new(
          filename: attachment.try(:original_filename).presence || blob.filename.to_s,
          content_type: attachment.try(:content_type).presence || blob.content_type,
          byte_size: attachment.try(:byte_size) || blob.byte_size,
          checksum: blob.checksum,
          identity: "#{child.try(:id)}:#{blob.id}",
          io_factory: lambda do |&block|
            raise SourceMissingError, "Missing blob for #{blob.id}" unless blob_exists?(blob)

            blob.open(&block)
          end
        )
      end

      def blob_exists?(blob)
        blob.respond_to?(:service) ? blob.service.exist?(blob.key) : true
      rescue StandardError
        false
      end
    end
  end
end

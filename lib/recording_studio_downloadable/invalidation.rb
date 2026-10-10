# frozen_string_literal: true

module RecordingStudioDownloadable
  module Invalidation
    ATTACHMENT_TYPE = "RecordingStudioAttachable::Attachment"

    module_function

    def invalidate!(recording:, action: nil, export_scope: nil, immediate: false, enqueue: true)
      return unless recording.respond_to?(:downloadable?) && recording.downloadable?

      identity_action = action || recording.downloadable_action
      identity_scope = export_scope || recording.downloadable_export_scope
      package = recording.downloadable_package(action: identity_action, export_scope: identity_scope)
      package&.mark_invalidated!

      return package unless enqueue
      return package if recording.downloadable_empty?

      wait = immediate ? nil : RecordingStudioDownloadable.configuration.debounce_wait
      Services::EnqueueGeneration.call(
        recording: recording,
        action: identity_action,
        export_scope: identity_scope,
        wait: wait,
        force: immediate
      ).value
    end

    def after_recording_commit(recording)
      return unless recording.is_a?(RecordingStudio::Recording)

      if attachment_recording?(recording)
        invalidate_parent_for_attachment!(recording)
      elsif recording.respond_to?(:downloadable?) && recording.downloadable?
        immediate = visibility_change?(recording)
        invalidate!(
          recording: recording,
          immediate: immediate,
          enqueue: recording.downloadable_package.present?
        )
      end
    rescue StandardError
      nil
    end

    def invalidate_parent_for_attachment!(recording)
      parent = recording.parent_recording
      parent ||= RecordingStudio::Recording.find_by(id: recording.parent_recording_id) if recording.parent_recording_id
      return if parent.blank?
      return unless parent.respond_to?(:downloadable?) && parent.downloadable?

      immediate = recording.trashed? || recording.destroyed? || trashed_changed?(recording)
      invalidate!(
        recording: parent,
        immediate: immediate,
        enqueue: parent.downloadable_package.present?
      )
    end

    def attachment_recording?(recording)
      recording.recordable_type.to_s == ATTACHMENT_TYPE
    end

    def visibility_change?(recording)
      trashed_changed?(recording)
    end

    def trashed_changed?(recording)
      return false unless recording.respond_to?(:saved_change_to_trashed_at?)

      recording.saved_change_to_trashed_at?
    rescue StandardError
      false
    end
  end
end

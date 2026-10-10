# frozen_string_literal: true

module RecordingStudioDownloadable
  class Package < ApplicationRecord
    self.table_name = "recording_studio_downloadable_packages"

    STATES = %w[pending processing ready failed].freeze
    DEFAULT_EXPORT_SCOPE = "public"

    belongs_to :recording, class_name: "RecordingStudio::Recording"
    has_one_attached :archive

    before_validation :assign_identity_defaults

    validates :format, presence: true
    validates :action, presence: true
    validates :export_scope, presence: true
    validates :state, presence: true, inclusion: { in: STATES }

    STATES.each do |value|
      define_method(:"#{value}?") { state == value }
    end

    def mark_processing!
      update!(state: "processing", failure_message: nil)
    end

    def mark_ready!(fingerprint:)
      update!(state: "ready", source_fingerprint: fingerprint, failure_message: nil)
    end

    def mark_failed!(message)
      update!(state: "failed", failure_message: message.to_s)
    end

    def mark_invalidated!
      update!(source_fingerprint: nil)
    end

    def stale_for?(fingerprint)
      source_fingerprint != fingerprint
    end

    def identity_matches?(action:, export_scope:)
      self.action.to_s == action.to_s && self.export_scope.to_s == export_scope.to_s
    end

    private

    def assign_identity_defaults
      self.export_scope = DEFAULT_EXPORT_SCOPE if export_scope.blank?
      return if action.present?
      return unless recording.respond_to?(:downloadable_action)

      self.action = recording.downloadable_action.to_s
    rescue StandardError
      self.action = "recordings.download" if action.blank?
    end
  end
end

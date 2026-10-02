# frozen_string_literal: true

module RecordingStudioDownloadable
  class Package < ApplicationRecord
    self.table_name = "recording_studio_downloadable_packages"

    STATES = %w[pending processing ready failed].freeze

    belongs_to :recording, class_name: "RecordingStudio::Recording"
    has_one_attached :archive

    validates :format, presence: true
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

    def stale_for?(fingerprint)
      source_fingerprint != fingerprint
    end
  end
end

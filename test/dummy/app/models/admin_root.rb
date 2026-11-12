# frozen_string_literal: true

class AdminRoot < ApplicationRecord
  recording_studio_recordable label: "Admin", root: true, shared: false
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
end

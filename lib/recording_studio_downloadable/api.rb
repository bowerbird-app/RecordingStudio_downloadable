# frozen_string_literal: true

require "recording_studio_downloadable/api/grant_scope"
require "recording_studio_downloadable/api/package_payload"
require "recording_studio_downloadable/api/download_recording"
require "recording_studio_downloadable/api/package_status"
require "recording_studio_downloadable/api/registration"

module RecordingStudioDownloadable
  module Api
    ACTION_VERSION = "1.0.0"
    INTERNAL_ROUTE_PARAMETER_KEYS = %i[api_key api_version].push("api_key", "api_version").freeze
    ACTIONS = {
      download: {
        http_verb: :post,
        handler: DownloadRecording,
        summary: "Start building the authorized ZIP for this recording.",
        description: "Authorizes the same download role as the HTML package, then enqueues generation."
      },
      package_status: {
        http_verb: :get,
        handler: PackageStatus,
        summary: "Read the current ZIP package for this recording.",
        description: "Authorizes the same download role as the HTML package, then reads the stored package."
      }
    }.freeze

    class << self
      def register_capability_action!
        Registration.register!
      end

      def download_role
        RecordingStudioDownloadable.configuration.auth_role_for(:download)
      end
    end
  end
end

# frozen_string_literal: true

require "recording_studio_downloadable/api/grant_scope"
require "recording_studio_downloadable/api/package_payload"
require "recording_studio_downloadable/api/download_recording"
require "recording_studio_downloadable/api/package_status"
require "recording_studio_downloadable/api/registration"

module RecordingStudioDownloadable
  module Api
    ACTION_VERSION = "1.0.0"
    ACTIONS = {
      downloadable_download: {
        http_verb: :post,
        handler: DownloadRecording,
        summary: "Build or queue the authorized ZIP for this recording.",
        description: "Authorizes with the global download role from Api.download_role " \
                     "(config.auth_roles :download). Recording Studio API refuses a weaker " \
                     "per-type auth role before the handler runs. Then builds or queues the " \
                     "ZIP and returns status, not a URL."
      },
      downloadable_package_status: {
        http_verb: :get,
        handler: PackageStatus,
        summary: "Read the current ZIP package for this recording.",
        description: "Authorizes with the same global download role from Api.download_role. " \
                     "Recording Studio API refuses a weaker per-type auth role before the " \
                     "handler runs. Then returns package status, not a download URL."
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

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
        summary: "POST builds or queues the ZIP and returns package status.",
        description: "POST member action. Enqueues a ZIP build when the package is missing or stale, " \
                     "then returns JSON. The body is state, ready, stale, failed, and failure_message. " \
                     "It has no ZIP bytes and no URL. The archive is fetched on the package route once " \
                     "ready is true. An empty file list is not found. A blocking download gate is forbidden. " \
                     "Over the rate limit is refused."
      },
      downloadable_package_status: {
        http_verb: :get,
        handler: PackageStatus,
        summary: "GET returns the current ZIP package status.",
        description: "GET member action. Reads the stored ZIP package and returns JSON. The body is " \
                     "state, ready, stale, failed, and failure_message. This call does not enqueue a build. " \
                     "It has no ZIP bytes and no URL. The archive is fetched on the package route once " \
                     "ready is true. A recording outside this API scope is not found."
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

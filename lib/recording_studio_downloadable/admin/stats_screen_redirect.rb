# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    # Admin turns a hidden screen into not-found. The redirect has to happen
    # before that resolve, and only Downloadable knows the gate decision.
    module StatsScreenRedirect
      def self.install!
        controller = RecordingStudioAdmin::ScreensController
        return if controller.private_method_defined?(:redirect_downloadable_stats_gate)

        controller.include(self)
        controller.before_action :redirect_downloadable_stats_gate
      end

      private

      def redirect_downloadable_stats_gate
        return unless downloadable_stats_screen?
        return if request.format.json?

        location = downloadable_stats_redirect
        redirect_to(location, allow_other_host: true) if location.present?
      end

      def downloadable_stats_redirect
        context = recording_studio_admin_context
        decision = RecordingStudioDownloadable::Authorization.send(
          :stats_gate_decision,
          actor: context.current_actor,
          recording: context.access_recording
        )
        decision.redirect_to unless decision.allowed?
      end

      def downloadable_stats_screen?
        [
          RecordingStudioDownloadable::Admin::SCREEN_KEY,
          RecordingStudioDownloadable::Admin::ROLLUP_SCREEN_KEY
        ].include?(params[:key].to_s)
      end
    end
  end
end

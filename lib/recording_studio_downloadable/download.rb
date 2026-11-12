# frozen_string_literal: true

module RecordingStudioDownloadable
  class << self
    def download!(recording:, actor:, controller: nil, capability_options: nil)
      Authorization.authorize!(
        action: recording.downloadable_action,
        actor: actor,
        recording: recording,
        capability_options: capability_options,
        controller: controller
      )
      deliver_package!(recording, controller)
    end

    private

    def deliver_package!(recording, controller)
      return continue_html_package_request!(controller, recording) if html_package_request?(controller)

      recording.downloadable_generate!(
        action: recording.downloadable_action,
        export_scope: recording.downloadable_export_scope,
        force: true
      )
    end

    def html_package_request?(controller)
      defined?(PackagesController) && controller.is_a?(PackagesController)
    end

    def continue_html_package_request!(controller, recording)
      gate = controller.send(:download_gate_for, recording)
      if controller.send(:download_gate_blocking?, gate, recording)
        controller.send(:respond_to_download_gate!, recording, gate)
        return
      end

      controller.send(:throttle_download!, recording)

      raise ActiveRecord::RecordNotFound if recording.downloadable_empty?

      controller.send(:serve_or_prepare!, recording)
    end
  end
end

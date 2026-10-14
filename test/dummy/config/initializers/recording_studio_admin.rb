# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  # The history page is one response: summary, chart frame, table frame, and the
  # People widget. Async widgets would leave that count as a skeleton.
  config.async_widgets.enabled = false

  config.access_recording_resolver = lambda do |context|
    if RecordingStudioDownloadable::Admin.recording_id?(context)
      RecordingStudioDownloadable::Admin.recording_for(context)
    elsif context.controller.respond_to?(:current_root_recording, true)
      context.controller.send(:current_root_recording)
    end
  end
end

Rails.application.config.to_prepare do
  if defined?(RecordingStudioAdmin::ApplicationController) && defined?(ApplicationHelper)
    RecordingStudioAdmin::ApplicationController.helper(ApplicationHelper)
  end
end

# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Render the mounted switcher pages inside the app shell when users visit them.
  config.layout = :application_layout

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    candidate_path = return_to.presence
    candidate_path = controller.main_app.root_path if candidate_path.blank?

    if internal_route?(candidate_path)
      candidate_path
    else
      controller.main_app.root_path
    end
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every workspace root in the dummy app."
    scope.available_roots = lambda do |**|
      Workspace.order(:name).filter_map do |workspace|
        RecordingStudio.root_recording_for(workspace)
      end
    end
    scope.access_check = ->(**) { true }

    # Admin screens refuse an access recording whose root is not the current
    # root. The home page and its History link are Studio Workspace, so start
    # there when this person can open it. Otherwise the first root they can
    # open. The list itself stays every workspace.
    scope.default_root = lambda do |roots:, actor: nil, **|
      accessible = roots.select do |recording|
        actor && RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end
      studio = accessible.find { |recording| recording.recordable.try(:name) == "Studio Workspace" }
      studio || accessible.first || roots.first
    end
  end
end

def internal_route?(path)
  routes = [
    Rails.application.routes,
    RecordingStudioRootSwitchable::Engine.routes
  ]

  routes.any? do |route_set|
    route_set.recognize_path(path, method: :get)
    true
  rescue StandardError
    false
  end
end

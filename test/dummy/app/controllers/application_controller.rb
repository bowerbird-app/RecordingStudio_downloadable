class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport
  include RecordingStudio::ControllerLayout

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  recording_studio_layout { application_layout }

  before_action :authenticate_user!
  before_action :set_current_actor
  before_action :remember_download_gate

  private

  def application_layout
    devise_controller? ? "application" : "flat_pack_sidebar"
  end

  def set_current_actor
    Current.actor = current_user
  end

  def remember_download_gate
    Current.download_gate = session[WorkspaceDownloadGate::SESSION_KEY]
  end
end

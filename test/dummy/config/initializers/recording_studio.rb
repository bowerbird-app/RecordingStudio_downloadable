# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "PressKit",
    "AdminRoot",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudio::Access",
    "RecordingStudio::AccessConstraint",
    "RecordingStudio::AccessRule",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::AdminApi",
    "RecordingStudioSiteSettings::SiteSetting"
  ]

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "Addon Template" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied.
  # Core 7 refuses a write with no actor. Requests set Current.actor from the
  # signed-in user. Tests that record before a request get a stable user.
  config.actor = lambda {
    current = Current.actor
    if current.present?
      current
    elsif Rails.env.test?
      User.find_or_create_by!(email: "recording-writes@example.com") do |user|
        user.password = "Password"
        user.password_confirmation = "Password"
      end
    end
  }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup

  # Core refuses a write until an authorizer is set. The dummy allows every write.
  config.authorize_write = lambda { |**|
    true
  }
end

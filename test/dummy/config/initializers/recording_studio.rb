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
    "RecordingStudioApi::AdminApi"
  ]

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "Addon Template" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup

  # Core 6.5+ refuses a write with no authorizer, and a blank actor raises
  # unless this flag is set. The dummy records before anyone is signed in.
  config.authorize_write = lambda { |**|
    true
  }
  config.allow_unauthorized_writes = true
end

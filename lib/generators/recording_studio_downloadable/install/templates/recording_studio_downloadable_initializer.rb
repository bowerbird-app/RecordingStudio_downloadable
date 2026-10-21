# frozen_string_literal: true

RecordingStudioDownloadable.configure do |config|
  # Fallback when an action is not listed in Accessible `config.action_audiences`.
  # Configured actions use RecordingStudioAccessible.authorized_action? instead.
  # config.auth_roles = { download: :view }

  # Optional override. Must respond to call(action:, actor:, recording:, role:).
  # When unset, Downloadable calls authorized_action? (or the role fallback).
  # config.authorize_with = nil

  # Per-action rate limits for download and generate requests.
  # config.rate_limits = {
  #   ip: { limit: 60, period: 1.minute },
  #   actor: { limit: 60, period: 1.minute },
  #   recording: { limit: 30, period: 1.minute }
  # }
  # config.max_concurrent_builds = 5
  # config.max_zip_bytes = 500.megabytes
  # config.content_change_debounce = 45.seconds

  # Host before_actions inherited from ApplicationController that would block
  # anonymous downloads. Authorization still runs on every engine endpoint.
  # config.skip_host_before_actions = %i[authenticate_user!]

  # Optional pre-download step. The host owns the form. Unregistered actions
  # download as usual. See README "Pre-download gate".
  # config.register_download_gate :"presskits.kit_download", Presskits::KitDownloadGate

  # Daily Logs summaries stay off until you install Logs run tables, migrate,
  # and rebuild downloadable/download_counts. History and Metrics stay on raw
  # download logs while this is false.
  # config.logs_summaries_enabled = false
end

# frozen_string_literal: true

require "i18n"

module RecordingStudioDownloadable
  # Rails I18n lookups for Downloadable user-facing copy. Every call site
  # passes `default:` English so a host locale without a fallback never shows
  # "translation missing". Keys live under `recording_studio.downloadable.*`.
  module Copy
    PREFIX = "recording_studio.downloadable"

    EMPTY_NOTICE = "Nothing to package."
    READY_NOTICE = "Download is ready."
    BUILDING_NOTICE = "Building ZIP. The download starts automatically when it is ready."
    NOT_READY_NOTICE = "This download is not ready yet."
    TIMEOUT_NOTICE = "Download is taking too long. Retry."

    DOWNLOAD_BUTTON = "Download"
    PREPARING_BUTTON = "Preparing…"
    RETRY_BUTTON = "Retry download"

    NOT_AUTHORIZED = "Not authorized to download this package"
    CAPABILITY_DISABLED = "Downloads are not enabled for this item"
    RATE_LIMITED = "Too many download requests. Try again shortly."
    CONCURRENT_BUILDS = "A download is already being built. Try again shortly."
    ARCHIVE_TOO_LARGE = "This download is too large to package."

    module_function

    def t(key, **options)
      I18n.t("#{PREFIX}.#{key}", **options)
    end

    # Map persisted / raised English failure strings to locale keys at render.
    # Unknown strings pass through unchanged.
    def failure_message(english)
      case english
      when EMPTY_NOTICE
        t("notices.empty", default: EMPTY_NOTICE)
      when ARCHIVE_TOO_LARGE
        t("errors.archive_too_large", default: ARCHIVE_TOO_LARGE)
      when NOT_READY_NOTICE
        t("notices.not_ready", default: NOT_READY_NOTICE)
      else
        english
      end
    end
  end
end

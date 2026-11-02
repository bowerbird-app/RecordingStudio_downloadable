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
    HISTORY_BUTTON = "History"

    HISTORY_TITLE = "Download history"
    HISTORY_SUBTITLE = "Newest first."
    SECTION_TITLE = "Downloads"
    SECTION_SUBTITLE = "Who grabbed the ZIP."
    ANONYMOUS = "Anonymous"
    SOMEONE = "Someone"
    UNKNOWN_ITEM = "Unknown item"
    WHAT_COLUMN = "What"
    STATS_DOWNLOADS = "Downloads"
    CHART_TITLE = "Downloads over time"

    NOT_AUTHORIZED = "Not authorized to download this package"
    CAPABILITY_DISABLED = "Downloads are not enabled for this item"
    RATE_LIMITED = "Too many download requests. Try again shortly."
    CONCURRENT_BUILDS = "A download is already being built. Try again shortly."
    ARCHIVE_TOO_LARGE = "This download is too large to package."

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end

    FAILURE_MESSAGE_KEYS = {
      EMPTY_NOTICE => "notices.empty",
      ARCHIVE_TOO_LARGE => "errors.archive_too_large",
      NOT_READY_NOTICE => "notices.not_ready"
    }.freeze

    # Pass-through-safe helper for known English failure strings. Unknown or
    # already-translated values return unchanged (main showed failure_message as-is).
    def failure_message(english)
      return english if english.blank?

      key = FAILURE_MESSAGE_KEYS[english]
      key ? t(key, default: english) : english
    end
  end
end

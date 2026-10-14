# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    class DownloadsSection < RecordingStudioAdmin::Section
      key SECTION_KEY
      icon :arrow_down_tray
      title { Copy.t("history.section_title", default: Copy::SECTION_TITLE) }
      subtitle { Copy.t("history.section_subtitle", default: Copy::SECTION_SUBTITLE) }

      link :history,
           text: ->(_context) { Copy.t("history.title", default: Copy::HISTORY_TITLE) },
           url: ->(context) { context.admin_screen_path(SCREEN_KEY) },
           style: :primary
    end
  end
end

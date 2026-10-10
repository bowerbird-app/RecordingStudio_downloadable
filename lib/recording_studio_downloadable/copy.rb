# frozen_string_literal: true

module RecordingStudioDownloadable
  module Copy
    PREFIX = "recording_studio.downloadable"

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end
  end
end

# frozen_string_literal: true

namespace :recording_studio_downloadable do
  namespace :download_logs do
    desc "Rebuild Logs daily download summaries for FROM..TO (inclusive UTC days)"
    task backfill_summaries: :environment do
      from = Date.iso8601(ENV.fetch("FROM"))
      to = Date.iso8601(ENV.fetch("TO"))
      RecordingStudioDownloadable::Services::RebuildDownloadLogSummaries.backfill!(from: from, to: to)
    end
  end
end

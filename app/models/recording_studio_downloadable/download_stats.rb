# frozen_string_literal: true

module RecordingStudioDownloadable
  class DownloadStats
    WINDOW = 30.days

    def initialize(recording)
      @logs = recording.downloadable_download_logs
    end

    def total
      @logs.count
    end

    def last_30_days
      @logs.where(occurred_at: WINDOW.ago..).count
    end

    def identified_people
      @logs.identified.pick(Arel.sql("COUNT(DISTINCT (actor_type, actor_id))")).to_i
    end
  end
end

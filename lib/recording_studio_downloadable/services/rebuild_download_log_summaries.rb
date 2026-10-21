# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class RebuildDownloadLogSummaries
      class << self
        def call(day:)
          new(day: day).call
        end

        def lookback!(lookback_days:)
          today = Time.now.utc.to_date
          dates = []
          Integer(lookback_days).downto(1) do |days_ago|
            date = today - days_ago
            call(day: date)
            dates << date
          end
          dates
        end

        def backfill!(from:, to:)
          date = from.to_date
          finish = to.to_date
          while date <= finish
            call(day: date)
            date += 1
          end
        end
      end

      def initialize(day:)
        @day = day.to_date
      end

      def call
        LogsRegistration.register!
        definition = LogsRegistration.download_counts_definition
        RecordingStudioLogs::Aggregation::Runner.call(
          definition,
          day: day,
          connection: LogsRegistration.logging_connection
        )
        day
      end

      private

      attr_reader :day
    end
  end
end

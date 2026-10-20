# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    module DownloadLogsSeries
      def series_for(context)
        return [] unless defined?(RecordingStudioMetrics)

        RecordingStudioMetrics::Admin.chart_series(
          MetricsRegistration::TIMESERIES_METRIC,
          admin_context: metrics_context(context),
          name: Copy.t("history.downloads", default: Copy::STATS_DOWNLOADS),
          interval: (context.filter_value(:group_by) || :day).to_sym,
          start_at: range_bound(context, :start_date),
          end_at: range_bound(context, :end_date),
          cache: false
        )
      end

      private

      # chart_series copies an Admin context's root recording into Metrics, and
      # Metrics then treats this exhaust table as a recordable. A Metrics context
      # is returned unchanged. The relation is already limited to this recording.
      def metrics_context(context)
        relation = context.query_result&.relation || DownloadLog.none
        MetricsRegistration.context_for(
          recording: context.access_recording,
          actor: context.current_actor,
          relation: relation.except(:order)
        )
      end

      def range_bound(context, edge)
        start_at, end_at = chart_bounds(context)
        edge == :start_date ? start_at : end_at
      end

      def chart_bounds(context)
        window = period_window(context.filter_value(:period))
        return [window.begin, window.end] if window

        all_time_bounds(context)
      end

      # Metrics refuses a reporting period longer than its maximum. All time on
      # the table is unbounded; the chart start is pulled forward to fit.
      def all_time_bounds(context)
        finish = Time.current.end_of_day
        start = earliest_occurred_at(context) || (finish - 1.day)
        start = [start, finish - chart_span_limit].max
        start = finish - 1.day if start >= finish
        [start, finish]
      end

      def earliest_occurred_at(context)
        relation = context.query_result&.relation
        return unless relation.respond_to?(:minimum)

        relation.minimum(:occurred_at)
      end

      def chart_span_limit
        RecordingStudioMetrics.configuration.max_reporting_period - 1.day
      end
    end
  end
end

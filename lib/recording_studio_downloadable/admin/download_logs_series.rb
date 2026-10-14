# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    module DownloadLogsSeries
      def series_for(context)
        return [] unless defined?(RecordingStudioMetrics)

        # chart_series returns [date, value] pairs. Flatpack's line chart does not
        # plot that shape. {x:, y:} points are what ApexCharts draws.
        plottable_series(metrics_series(context))
      end

      private

      def plottable_series(series)
        series.map { |entry| entry.merge(data: plottable_points(entry[:data])) }
      end

      def plottable_points(points)
        Array(points).map { |point| { x: point[0], y: point[1] } }
      end

      def metrics_series(context)
        relation = context.query_result&.relation || DownloadLog.none
        RecordingStudioMetrics::Admin.chart_series(
          MetricsRegistration::TIMESERIES_METRIC,
          admin_context: metrics_context(context, relation),
          name: Copy.t("history.downloads", default: Copy::STATS_DOWNLOADS),
          interval: (context.filter_value(:group_by) || :day).to_sym,
          start_at: range_bound(context, :start_date),
          end_at: range_bound(context, :end_date),
          cache: false
        )
      end

      # chart_series copies an Admin context's root recording into Metrics, and
      # Metrics then treats this exhaust table as a recordable. A Metrics context
      # is returned unchanged. The relation is already limited to this recording.
      def metrics_context(context, relation)
        MetricsRegistration.context_for(
          recording: context.access_recording,
          actor: context.current_actor,
          relation: relation.except(:order)
        )
      end

      def range_bound(context, edge)
        date = context.filter_value(:date_range)&.public_send(edge)
        return if date.nil?

        edge == :start_date ? date.beginning_of_day : date.end_of_day
      end
    end
  end
end

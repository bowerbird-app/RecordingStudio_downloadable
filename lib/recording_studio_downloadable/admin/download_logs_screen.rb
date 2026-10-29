# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    class DownloadLogsScreen < RecordingStudioAdmin::Screen
      # Admin's date_range filter always renders a free calendar, and Period has
      # no all-time preset. These keys are Period presets plus all_time.
      PERIOD_KEYS = %w[last_7_days last_4_weeks last_3_months last_12_months all_time].freeze
      DEFAULT_PERIOD = "last_4_weeks"

      key SCREEN_KEY
      icon :arrow_down_tray
      title { Copy.t("history.title", default: Copy::HISTORY_TITLE) }
      subtitle { Copy.t("history.subtitle", default: Copy::HISTORY_SUBTITLE) }
      visible_if { |context| DownloadLogsScreen.allowed?(context) }

      query { |context| DownloadLogsScreen.relation_for(context) }

      filter :period, values: PERIOD_KEYS, apply: lambda { |relation, value, context|
        DownloadLogsScreen.apply_period(relation, value, context)
      }
      filter :what, options: -> { DownloadLogsScreen.item_choices }, apply: lambda { |relation, value, context|
        DownloadLogsScreen.apply_item(relation, value, context)
      }
      filter :group_by, values: %i[day week month], default: :day
      filter :person, options: -> { DownloadLogsScreen.person_choices }, apply: lambda { |relation, value, context|
        DownloadLogsScreen.apply_person(relation, value, context)
      }
      filter_presentation :inline

      summary do
        label { Copy.t("history.downloads", default: Copy::STATS_DOWNLOADS) }
        period_label { |context| DownloadLogsScreen.period_label_for(context) }
      end

      chart do
        title { Copy.t("history.chart_title", default: Copy::CHART_TITLE) }
        type :line
        series { |context| DownloadLogsScreen.series_for(context) }
      end

      table do
        column :occurred_at, title: "When"
        column :who, title: "Who", sortable: false, value: ->(row, _context) { row.person_label }
        column :what, title: Copy.t("history.what", default: Copy::WHAT_COLUMN), sortable: false,
                      value: ->(row, _context) { DownloadLogsScreen.item_label(row) }
        default_columns :occurred_at, :who
        default_sort :occurred_at, direction: :desc
        paginate per_page: 20
      end

      extend DownloadLogsQueries
      extend DownloadLogsSeries

      def self.filters
        declared = super
        return declared if item_choices.any?

        declared.reject { |filter| filter.param_key == :what }
      end
    end
  end
end

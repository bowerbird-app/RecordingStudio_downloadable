# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    # Admin's date_range filter always renders a free calendar, and Period has
    # no all-time preset. These keys are Period presets plus all_time.
    module DownloadLogsDeclaration
      PERIOD_KEYS = %w[last_7_days last_4_weeks last_3_months last_12_months all_time].freeze
      DEFAULT_PERIOD = "last_4_weeks"

      def declare_download_logs_screen!(screen_key)
        screen = self
        key screen_key
        icon :arrow_down_tray
        title { Copy.t("history.screen_title", default: Copy::SCREEN_TITLE) }
        visible_if { |context| screen.allowed?(context) }
        query { |context| screen.relation_for(context) }
        declare_history_filters!(screen)
        declare_history_summary!(screen)
        declare_history_chart!(screen)
        declare_history_table!(screen)
      end

      private

      def declare_history_filters!(screen)
        filter :period, values: PERIOD_KEYS, apply: lambda { |relation, value, context|
          screen.apply_period(relation, value, context)
        }
        filter :group_by, values: %i[day week month], default: :week
        filter :person, label: -> { Copy.t("history.who", default: Copy::WHO_FILTER) },
                        options: -> { screen.person_choices },
                        apply: lambda { |relation, value, context|
                          screen.apply_person(relation, value, context)
                        }
        filter_presentation :inline
      end

      def declare_history_summary!(screen)
        summary do
          label { Copy.t("history.downloads", default: Copy::STATS_DOWNLOADS) }
          period_label { |context| screen.period_label_for(context) }
        end
      end

      def declare_history_chart!(screen)
        chart do
          title { Copy.t("history.chart_title", default: Copy::CHART_TITLE) }
          type :line
          series { |context| screen.series_for(context) }
          # Flatpack's smooth curve is drawn in 0..1 while Admin's count axis
          # runs 0..max, so a week of 3 downloads paints near 0.6.
          options({ stroke: { curve: "straight", width: 2 } })
        end
      end

      def declare_history_table!(screen)
        table do
          title Copy.t("history.table_title", default: Copy::TABLE_TITLE)
          column :occurred_at, title: "When"
          column :who, title: "Who", sortable: false, value: ->(row, _context) { row.person_label }
          column :what, title: Copy.t("history.what", default: Copy::WHAT_COLUMN), sortable: false,
                        value: ->(row, _context) { screen.item_label(row) }
          default_columns :occurred_at, :who
          default_sort :occurred_at, direction: :desc
          paginate per_page: 20
        end
      end
    end

    class DownloadLogsScreen < RecordingStudioAdmin::Screen
      extend DownloadLogsQueries
      extend DownloadLogsSeries
      extend DownloadLogsScope
      extend DownloadLogsDeclaration

      declare_download_logs_screen!(SCREEN_KEY)
    end

    class DownloadLogsRollupScreen < RecordingStudioAdmin::Screen
      extend DownloadLogsQueries
      extend DownloadLogsSeries
      extend DownloadLogsScope
      extend DownloadLogsDeclaration

      declare_download_logs_screen!(ROLLUP_SCREEN_KEY)
    end
  end
end

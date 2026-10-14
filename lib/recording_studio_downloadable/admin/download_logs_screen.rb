# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    class DownloadLogsScreen < RecordingStudioAdmin::Screen
      key SCREEN_KEY
      icon :arrow_down_tray
      title { Copy.t("history.title", default: Copy::HISTORY_TITLE) }
      subtitle { Copy.t("history.subtitle", default: Copy::HISTORY_SUBTITLE) }
      visible_if { |context| DownloadLogsScreen.allowed?(context) }

      query { |context| DownloadLogsScreen.relation_for(context) }

      filter :date_range, field: :occurred_at, default: :last_30_days
      filter :group_by, values: %i[day week month], default: :day
      filter :download, options: -> { DownloadLogsScreen.download_choices }, apply: lambda { |relation, value, context|
        DownloadLogsScreen.apply_download(relation, value, context)
      }
      filter :person, options: -> { DownloadLogsScreen.person_choices }, apply: lambda { |relation, value, context|
        DownloadLogsScreen.apply_person(relation, value, context)
      }
      filter_presentation :inline

      summary do
        label { Copy.t("history.downloads", default: Copy::STATS_DOWNLOADS) }
      end

      chart do
        title { Copy.t("history.chart_title", default: Copy::CHART_TITLE) }
        type :line
        series { |context| DownloadLogsScreen.series_for(context) }
      end

      table do
        column :occurred_at, title: "When"
        column :who, title: "Who", sortable: false, value: ->(row, _context) { row.person_label }
        column :action, title: "Download"
        default_columns :occurred_at, :who, :action
        default_sort :occurred_at, direction: :desc
        paginate per_page: 20
      end

      widget "widgets.download_logs.people"

      extend DownloadLogsQueries
      extend DownloadLogsSeries
    end
  end
end

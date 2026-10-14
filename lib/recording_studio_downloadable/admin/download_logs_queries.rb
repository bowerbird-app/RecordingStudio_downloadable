# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    module DownloadLogsQueries
      def people_widget
        @people_widget ||= build_people_widget
      end

      def allowed?(context)
        recording = context.access_recording
        return false if recording.nil?

        Authorization.view_logs_allowed?(actor: context.current_actor, recording: recording)
      end

      def relation_for(context)
        recording = context.access_recording
        Admin.remember_recording(recording)
        return DownloadLog.none if recording.nil? || !allowed?(context)

        recording.downloadable_download_logs
      end

      def download_choices
        recording = Admin.remembered_recording
        return [] unless recording

        recording.downloadable_download_logs.distinct.order(:action).pluck(:action)
      end

      def person_choices
        recording = Admin.remembered_recording
        return [] unless recording

        labels = []
        labels << "anonymous" if recording.downloadable_download_logs.exists?(actor_id: nil)
        recording.downloadable_download_logs.identified.find_each { |log| labels << log.person_label }
        labels.uniq
      end

      def apply_download(relation, value, _context)
        relation.where(action: value)
      end

      def apply_person(relation, value, _context)
        return relation.where(actor_id: nil) if value.to_s == "anonymous"

        match = person_match(value)
        return relation.none unless match

        relation.where(actor_type: match.actor_type, actor_id: match.actor_id)
      end

      def people_count(context)
        relation = context.query_result&.relation
        return 0 unless relation

        DownloadLog.identified_count(relation)
      end

      private

      def build_people_widget
        RecordingStudioAdmin::Widget.new("widgets.download_logs.people") do
          type :number
          title { Copy.t("history.people", default: Copy::STATS_PEOPLE) }
          info { Copy.t("history.people_info", default: Copy::STATS_PEOPLE_INFO) }
          hide_change
          hide_period
          value { |context| DownloadLogsScreen.people_count(context) }
        end
      end

      def person_match(value)
        recording = Admin.remembered_recording
        return unless recording

        recording.downloadable_download_logs.identified.find { |log| log.person_label == value }
      end
    end
  end
end

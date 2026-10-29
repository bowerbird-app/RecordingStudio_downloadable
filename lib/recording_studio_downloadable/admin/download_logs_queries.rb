# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    module DownloadLogsQueries
      def allowed?(context)
        recording = context.access_recording
        return false if recording.nil?

        Authorization.view_logs_allowed?(actor: context.current_actor, recording: recording)
      end

      def relation_for(context)
        recording = context.access_recording
        scope = HistoryScope.from_params(context.params)
        Admin.remember_recording(recording)
        Admin.remember_history_scope(scope)
        stamp_default_period!(context)
        stamp_subtree_columns!(context, scope)
        return DownloadLog.none if recording.nil? || !allowed?(context)

        logs_relation(recording, scope)
      end

      def apply_period(relation, value, _context)
        scoped = relation.unscope(where: :occurred_at)
        window = period_window(value)
        return scoped unless window

        scoped.where(occurred_at: window)
      end

      def period_window(value)
        key = value.presence&.to_s || DownloadLogsScreen::DEFAULT_PERIOD
        return if key == "all_time"

        period = RecordingStudioAdmin::Period.from_preset_key(key)
        return unless period&.start_date && period.end_date

        period.start_date.beginning_of_day..period.end_date.end_of_day
      end

      def period_label_for(context)
        key = context.filter_value(:period).presence || DownloadLogsScreen::DEFAULT_PERIOD
        key.to_s.humanize
      end

      def person_choices
        recording = Admin.remembered_recording
        return [] unless recording

        relation = logs_relation(recording)
        labels = []
        labels << "anonymous" if relation.exists?(actor_id: nil)
        relation.identified.find_each { |log| labels << log.person_label }
        labels.uniq
      end

      def apply_person(relation, value, _context)
        return relation.where(actor_id: nil) if value.to_s == "anonymous"

        match = person_match(value)
        return relation.none unless match

        relation.where(actor_type: match.actor_type, actor_id: match.actor_id)
      end

      def item_label(log)
        recording = log.recording
        return Copy.t("history.unknown_item", default: Copy::UNKNOWN_ITEM) if recording.nil?

        recording.name.presence || recording.type_label.presence ||
          Copy.t("history.unknown_item", default: Copy::UNKNOWN_ITEM)
      end

      def logs_relation(recording, scope = Admin.remembered_history_scope)
        scope ||= HistoryScope.item
        relation = scope.logs_for(recording)
        return relation unless relation.respond_to?(:includes)

        relation.includes(:recording)
      end

      private

      # Select filters ignore default:, so a missing param would show "All"
      # while the rows stayed unfiltered. Stamp the default before filters run.
      def stamp_default_period!(context)
        params = context.params
        return unless params.respond_to?(:[]=)
        return if params[:period].present? || params["period"].present?

        params["period"] = DownloadLogsScreen::DEFAULT_PERIOD
      end

      def stamp_subtree_columns!(context, scope)
        return unless scope.subtree

        params = context.params
        return unless params.respond_to?(:[]=)
        return if params[:columns].present? || params["columns"].present?

        params["columns"] = scope.table_columns
      end

      def person_match(value)
        recording = Admin.remembered_recording
        return unless recording

        logs_relation(recording).identified.find { |log| log.person_label == value }
      end
    end
  end
end

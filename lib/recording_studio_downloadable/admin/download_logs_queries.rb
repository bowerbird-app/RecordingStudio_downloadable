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
        Admin.remember_recording(recording)
        stamp_default_period!(context)
        return DownloadLog.none if recording.nil? || !allowed?(context)

        ids = recording_ids_for(context, recording)
        Admin.remember_log_ids(ids)
        stamp_item_column!(context)
        logs_for_ids(ids)
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
        relation = logs_for_ids(Admin.remembered_log_ids)
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
        name = log.recording&.name
        name.presence || Copy.t("history.unknown_item", default: Copy::UNKNOWN_ITEM)
      end

      private

      def recording_ids_for(context, recording)
        return [recording.id] unless scopeable?

        context.scoped_recording_ids
      end

      def logs_for_ids(ids)
        return DownloadLog.none if ids.blank?

        DownloadLog.where(recording_id: ids).includes(:recording)
      end

      # Select filters ignore default:, so a missing param would show "All"
      # while the rows stayed unfiltered. Stamp the default before filters run.
      def stamp_default_period!(context)
        params = context.params
        return unless params.respond_to?(:[]=)
        return if params[:period].present? || params["period"].present?

        params["period"] = DownloadLogsScreen::DEFAULT_PERIOD
      end

      def stamp_item_column!(context)
        return unless scopeable?

        params = context.params
        return unless params.respond_to?(:[]=)
        return if params[:columns].present? || params["columns"].present?

        params["columns"] = DownloadLogsScope::ITEM_COLUMNS
      end

      def person_match(value)
        logs_for_ids(Admin.remembered_log_ids).identified.find { |log| log.person_label == value }
      end
    end
  end
end

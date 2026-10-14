# frozen_string_literal: true

module RecordingStudioDownloadable
  class DownloadLogFilters
    attr_reader :download, :person, :from, :to

    def initialize(recording, raw)
      @recording = recording
      @download = raw[:download].to_s.presence
      @person = raw[:person].to_s.presence
      @from = parse_day(raw[:from])
      @to = parse_day(raw[:to])
    end

    def relation
      scope = @recording.downloadable_download_logs
      scope = scope.where(action: @download) if @download
      scope = filter_person(scope)
      scope = scope.where(occurred_at: @from.beginning_of_day..) if @from
      scope = scope.where(occurred_at: ..@to.end_of_day) if @to
      scope.recent
    end

    def active?
      @download.present? || @person.present? || @from.present? || @to.present?
    end

    def download_choices
      actions = @recording.downloadable_download_logs.distinct.order(:action).pluck(:action)
      actions |= [@download] if @download.present?
      [["Any", ""]] + actions.map { |action| [action, action] }
    end

    def person_choices
      [["Anyone", ""], ["Anonymous", "anonymous"]] + identified_people
    end

    private

    def filter_person(scope)
      return scope if @person.blank?
      return scope.where(actor_id: nil) if @person == "anonymous"

      actor_type, actor_id = @person.split(":", 2)
      return scope.none if actor_type.blank? || actor_id.blank?

      scope.where(actor_type: actor_type, actor_id: actor_id)
    end

    def identified_people
      rows = @recording.downloadable_download_logs.identified.distinct.pluck(:actor_type, :actor_id)
      rows.map do |actor_type, actor_id|
        [person_label(actor_type, actor_id), "#{actor_type}:#{actor_id}"]
      end
    end

    def person_label(actor_type, actor_id)
      person = actor_type.to_s.safe_constantize&.find_by(id: actor_id)
      person.try(:name).presence || person.try(:email).presence || Copy.t("history.someone", default: Copy::SOMEONE)
    end

    def parse_day(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end

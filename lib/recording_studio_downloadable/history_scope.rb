# frozen_string_literal: true

module RecordingStudioDownloadable
  HistoryScope = Data.define(:subtree, :requested_types)

  class HistoryScope
    SUBTREE = "subtree"
    ITEM_COLUMNS = %w[occurred_at who].freeze
    SUBTREE_COLUMNS = %w[what occurred_at who].freeze

    class << self
      def item
        new(subtree: false, requested_types: [])
      end

      def from_params(params)
        new(
          subtree: subtree_flag?(param(params, :scope)),
          requested_types: normalize_types(param(params, :recordable_type))
        )
      end

      def from_options(options)
        options = options.to_h
        new(
          subtree: subtree_flag?(options[:scope]),
          requested_types: normalize_types(options[:recordable_type])
        )
      end

      def subtree_flag?(value)
        value.to_s == SUBTREE
      end

      def param(params, key)
        return if params.blank?

        params[key] || params[key.to_s]
      end

      def normalize_types(raw)
        Array(raw).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?).uniq
      end
    end

    def logs_for(recording)
      return DownloadLog.none if recording.nil?
      return recording.downloadable_download_logs unless subtree

      ids = recording_ids_for(recording)
      return DownloadLog.none if ids.empty?

      DownloadLog.where(recording_id: ids)
    end

    def recording_ids_for(recording)
      return [] if recording.nil? || !subtree
      return [] unless recording.respond_to?(:descendant_ids)

      ids = recording.descendant_ids(include_self: true)
      return [] if ids.empty?
      return ids unless type_filter?

      declared = declared_types
      return [] if declared.empty?

      RecordingStudio::Recording.unscoped.where(id: ids, recordable_type: declared).pluck(:id)
    end

    def type_filter?
      requested_types.any?
    end

    def declared_types
      requested_types.filter_map { |name| declared_type_name(name) }.uniq
    end

    def query_params(recording_id:)
      params = { recording_id: recording_id }
      params[:scope] = SUBTREE if subtree
      params[:recordable_type] = query_type_value if type_filter?
      params
    end

    def table_columns
      subtree ? SUBTREE_COLUMNS : ITEM_COLUMNS
    end

    def type_choices(recording)
      (descendant_declared_types(recording) | declared_types).sort
    end

    private

    def declared_type_name(name)
      return unless defined?(RecordingStudio)
      return unless RecordingStudio.respond_to?(:recordable_declaration_defined?)
      return unless RecordingStudio.recordable_declaration_defined?(name)

      if RecordingStudio.respond_to?(:recordable_type_name)
        RecordingStudio.recordable_type_name(name)
      else
        name
      end
    end

    def query_type_value
      requested_types.size == 1 ? requested_types.first : requested_types
    end

    def descendant_declared_types(recording)
      return [] unless recording.respond_to?(:descendant_ids)

      ids = recording.descendant_ids(include_self: true)
      return [] if ids.empty?
      return [] unless defined?(RecordingStudio::Recording)

      names = RecordingStudio::Recording.unscoped.where(id: ids).distinct.pluck(:recordable_type)
      names.select { |name| declared_type_name(name) }
    end
  end
end

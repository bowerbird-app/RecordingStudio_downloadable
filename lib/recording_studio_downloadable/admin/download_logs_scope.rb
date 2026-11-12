# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    module DownloadLogsScope
      ITEM_COLUMNS = %w[what occurred_at who].freeze

      def install_scope!
        types = history_types
        clear_scope_filters!
        return if types.empty?

        scopeable recordable_types: types
        label_kind_filter(types)
        types.each { |type_name| add_item_filter(type_name) }
      end

      def item_filter_key(type_name)
        :"item_#{type_name.to_s.underscore.tr('/', '_')}"
      end

      def history_types
        configured = RecordingStudioDownloadable.configuration.history_recordable_types
        return configured unless configured.nil?

        opted_in_types
      end

      private

      def clear_scope_filters!
        @scopeable_recordable_types = nil
        filters.delete_if { |entry| scope_filter?(entry) }
      end

      def scope_filter?(entry)
        entry.key == :recordable_type || entry.type.to_sym == :within
      end

      def label_kind_filter(types)
        filter :recordable_type, label: kind_label, values: type_choices(types)
      end

      def kind_label
        -> { Copy.t("history.kind", default: Copy::KIND_FILTER) }
      end

      def type_choices(types)
        types.map { |type_name| { value: type_name, label: type_label(type_name) } }
      end

      def add_item_filter(type_name)
        filter item_filter_key(type_name), type: :within, recordable_type: type_name,
                                           label: item_label_for(type_name),
                                           all_label: all_items_label,
                                           name: item_name
      end

      def item_label_for(type_name)
        english = type_label(type_name)
        -> { Copy.t("history.within.#{type_name.underscore.tr('/', '.')}", default: english) }
      end

      def all_items_label
        -> { Copy.t("history.within_all", default: Copy::WITHIN_ALL) }
      end

      def item_name
        lambda { |recording|
          recording.name.presence || Copy.t("history.unknown_item", default: Copy::UNKNOWN_ITEM)
        }
      end

      def type_label(type_name)
        declaration = recordable_declaration(type_name)
        declaration&.label.presence || type_name.underscore.humanize
      end

      def recordable_declaration(type_name)
        return unless RecordingStudio.respond_to?(:recordable_declaration_for)

        RecordingStudio.recordable_declaration_for(type_name)
      end

      def opted_in_types
        return [] unless defined?(RecordingStudio)

        load_recordable_types!
        RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
      end

      def load_recordable_types!
        declarations = RecordingStudio::RecordableDeclarations
        declarations.ensure_loaded! if declarations.respond_to?(:ensure_loaded!)
      end
    end
  end
end

# frozen_string_literal: true

module RecordingStudioDownloadable
  module Admin
    # Admin's :within filter assumes the screen relation is Recording and
    # filters `id`. Download logs are a different table, so a picked item
    # has to narrow `recording_id` instead.
    module WithinLogFilter
      def apply(relation, value, context)
        return super unless download_logs?(relation)
        return relation if value.nil?

        ids = context.within_catalog_for(@definition).subtree_ids(value)
        relation.where(recording_id: ids)
      end

      private

      def download_logs?(relation)
        relation.respond_to?(:klass) && relation.klass == DownloadLog
      end
    end
  end
end

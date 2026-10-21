# frozen_string_literal: true

module RecordingStudioDownloadable
  class DownloadLog < ApplicationRecord
    self.table_name = "recording_studio_downloadable_download_logs"

    USER_AGENT_LIMIT = 512
    APPEND_ONLY_MESSAGE = "Download logs are append-only"

    belongs_to :recording, class_name: "RecordingStudio::Recording",
                           inverse_of: :downloadable_download_logs
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :impersonator, polymorphic: true, optional: true

    scope :recent, -> { order(occurred_at: :desc, created_at: :desc) }
    scope :identified, -> { where.not(actor_id: nil) }

    def self.identified_count(relation)
      scoped = relation.respond_to?(:except) ? relation.except(:order) : relation
      scoped.where.not(actor_id: nil).pick(Arel.sql("COUNT(DISTINCT (actor_type, actor_id))")).to_i
    end

    before_validation :truncate_user_agent
    before_validation :assign_defaults
    before_validation :sanitize_metadata_column
    before_update :raise_append_only_error
    before_destroy :raise_append_only_error

    validates :action, presence: true
    validates :export_scope, presence: true
    validates :occurred_at, presence: true

    # rubocop:disable-next Metrics/ParameterLists
    def self.record!(recording:, action:, export_scope:, actor: nil, impersonator: nil,
                     ip_address: nil, user_agent: nil, occurred_at: nil, metadata: nil)
      create!(
        recording: recording,
        action: action.to_s,
        export_scope: export_scope.presence&.to_s || "public",
        actor: actor,
        impersonator: impersonator,
        ip_address: ip_address,
        user_agent: user_agent,
        occurred_at: occurred_at || Time.current, metadata: metadata
      )
    end

    def metadata=(raw)
      super(DownloadLogMetadata.clean(raw))
    end

    def readonly?
      persisted?
    end

    def delete
      raise_append_only_error
    end

    def person_label
      return Copy.t("history.anonymous", default: Copy::ANONYMOUS) if actor_id.blank?

      person = actor
      name = person.try(:name).presence || person.try(:email).presence
      name.presence || Copy.t("history.someone", default: Copy::SOMEONE)
    end

    private

    def truncate_user_agent
      return if user_agent.blank?

      self.user_agent = user_agent.to_s[0, USER_AGENT_LIMIT]
    end

    def assign_defaults
      self.export_scope = "public" if export_scope.blank?
      self.occurred_at ||= Time.current
      self.metadata = {} if metadata.nil?
      self.root_recording_id ||= recording&.root_recording_id.presence || recording&.id
    end

    def sanitize_metadata_column
      self.metadata = DownloadLogMetadata.clean(metadata)
    end

    def raise_append_only_error
      raise ActiveRecord::ReadOnlyRecord, APPEND_ONLY_MESSAGE
    end
  end
end

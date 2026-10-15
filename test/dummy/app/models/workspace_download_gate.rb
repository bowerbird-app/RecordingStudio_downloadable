# frozen_string_literal: true

# Example host gate. Only the seeded "Gated Download" workspace is held.
# Other workspaces.download actions stay on the normal button.
class WorkspaceDownloadGate
  NAME = "Gated Download"
  SESSION_KEY = :workspace_download_gate

  def self.applies?(recording)
    recording&.recordable.try(:name) == NAME
  end

  def self.satisfied?(recording:, actor:, request:)
    return true unless applies?(recording)

    entry = entry_for(recording, entries(request&.session&.[](SESSION_KEY)))
    confirmed?(entry)
  end

  def self.continuation_url(recording:, actor:, request:)
    Rails.application.routes.url_helpers.download_gate_path(recording_id: recording.id)
  end

  def self.component
    WorkspaceDownloadGateComponent
  end

  def self.metadata_for(recording:, actor:)
    return {} unless applies?(recording)

    entry = entry_for(recording, entries(Current.download_gate))
    return {} unless confirmed?(entry)

    { "recipient" => entry["recipient"].to_s, "confirmed" => true }
  end

  def self.entries(store)
    return {} unless store.is_a?(Hash)

    store.each_with_object({}) do |(key, value), memo|
      next unless value.is_a?(Hash)

      memo[key.to_s] = value.stringify_keys
    end
  end

  def self.entry_for(recording, entries)
    entries[recording.id.to_s] || {}
  end

  def self.confirmed?(entry)
    entry["confirmed"] == true && entry["recipient"].present?
  end
end

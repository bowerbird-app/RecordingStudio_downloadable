# frozen_string_literal: true

class WorkspaceDownloadGateComponent < ViewComponent::Base
  def initialize(recording:, actor:, action:)
    @recording = recording
    @actor = actor
    @action = action
  end

  def call
    helpers.tag.div(**wrapper_attributes) do
      helpers.safe_join([download_button, modal])
    end
  end

  private

  def wrapper_attributes
    {
      data: {
        controller: "workspace-download-gate",
        workspace_download_gate_modal_id_value: WorkspaceDownloadGate.modal_id(@recording),
        action: "recording-studio-downloadable:download-gate@window->workspace-download-gate#hold"
      }
    }
  end

  def download_button
    helpers.render(FlatPack::Button::Component.new(
      text: "Download",
      style: :primary,
      size: :md,
      type: "button",
      data: { "modal-id": WorkspaceDownloadGate.modal_id(@recording) }
    ))
  end

  def modal
    helpers.render(
      FlatPack::Modal::Component.new(
        id: WorkspaceDownloadGate.modal_id(@recording),
        title: "Before you download",
        size: :md
      )
    ) do |modal|
      modal.body do
        helpers.render(FlatPack::Card::Body::Component.new(padding: :lg)) do
          helpers.render("download_gates/frame", recording: @recording)
        end
      end
    end
  end
end

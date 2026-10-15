# frozen_string_literal: true

class WorkspaceDownloadGateComponent < ViewComponent::Base
  def initialize(recording:, actor:, action:)
    @recording = recording
    @actor = actor
    @action = action
  end

  def call
    recipient.present? ? confirm_step : name_step
  end

  private

  def recipient
    entry["recipient"].to_s
  end

  def entry
    store = helpers.request.session[WorkspaceDownloadGate::SESSION_KEY]
    WorkspaceDownloadGate.entry_for(@recording, WorkspaceDownloadGate.entries(store))
  end

  def name_step
    gate_form("name") do
      helpers.safe_join([
        helpers.render(FlatPack::TextInput::Component.new(
          name: "recipient",
          label: "Your name",
          placeholder: "Ava Chen",
          required: true
        )),
        helpers.render(FlatPack::Button::Component.new(
          text: "Continue",
          style: :primary,
          size: :md,
          type: "submit"
        ))
      ])
    end
  end

  def confirm_step
    gate_form("confirm") do
      helpers.safe_join([
        helpers.render(FlatPack::Checkbox::Component.new(
          name: "confirmed",
          label: "Send me the ZIP",
          required: true,
          help_text: "For #{recipient}."
        )),
        helpers.render(FlatPack::Button::Component.new(
          text: "Confirm",
          style: :primary,
          size: :md,
          type: "submit"
        ))
      ])
    end
  end

  def gate_form(step, &block)
    helpers.form_with(url: helpers.download_gate_path, method: :patch) do
      helpers.safe_join([
        helpers.hidden_field_tag(:recording_id, @recording.id),
        helpers.hidden_field_tag(:step, step),
        block.call
      ])
    end
  end
end

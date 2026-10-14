# frozen_string_literal: true

class DownloadAccessComponent < ViewComponent::Base
  def initialize(recording:, actor:, action:)
    @recording = recording
    @actor = actor
    @action = action
  end

  def call
    render FlatPack::Alert::Component.new(
      title: "Ask for access",
      description: "You need access before this download opens.",
      style: :info
    )
  end
end

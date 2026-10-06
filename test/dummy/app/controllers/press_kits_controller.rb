# frozen_string_literal: true

class PressKitsController < ApplicationController
  def index
    recordings = RecordingStudio::Recording.where(recordable_type: "PressKit", trashed_at: nil).to_a
    recordings_by_id = recordings.index_by(&:recordable_id)
    kits = recordings.filter_map(&:recordable)

    @kit_rows = kits.sort_by { |kit| [kit.name.to_s, kit.created_at] }.map do |kit|
      recording = recordings_by_id[kit.id]
      {
        name: kit.name.presence || "Untitled kit",
        description: description_snippet(kit.description),
        recording: recording,
        press_kit: kit
      }
    end
  end

  def edit
    load_press_kit!
  end

  def update
    load_press_kit!
    @recording.root_recording.revise(@recording, actor: current_user) do |kit|
      kit.description = press_kit_params[:description]
    end

    redirect_to press_kits_path, notice: "Saved. Download again to pack the new description."
  end

  private

  def load_press_kit!
    @press_kit = PressKit.find(params[:id])
    @recording = RecordingStudio::Recording.find_by!(recordable: @press_kit, trashed_at: nil)
  end

  def press_kit_params
    params.require(:press_kit).permit(:description)
  end

  def description_snippet(text)
    return "—" if text.blank?

    view_context.truncate(text.to_s.squish, length: 80)
  end
end

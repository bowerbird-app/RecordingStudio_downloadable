# frozen_string_literal: true

class DownloadGatesController < ApplicationController
  def show
    @recording = gated_recording
    return if performed?
  end

  def update
    recording = gated_recording
    return if performed?

    entries = WorkspaceDownloadGate.entries(session[WorkspaceDownloadGate::SESSION_KEY])
    entry = entries[recording.id.to_s] || {}
    message, flash = store_step(entry)
    entries[recording.id.to_s] = entry
    session[WorkspaceDownloadGate::SESSION_KEY] = entries
    Current.download_gate = entries

    redirect_to download_gate_path(recording_id: recording.id), flash => message
  end

  private

  def gated_recording
    recording = RecordingStudio::Recording.find_by(id: params[:recording_id])
    if recording.nil? || recording.try(:trashed_at).present? || !WorkspaceDownloadGate.applies?(recording)
      raise ActiveRecord::RecordNotFound
    end

    unless RecordingStudioDownloadable::Authorization.allowed?(
      action: recording.downloadable_action,
      actor: current_user,
      recording: recording
    )
      head :forbidden
      return
    end

    recording
  end

  def store_step(entry)
    if params[:step].to_s == "confirm"
      confirm_step(entry)
    else
      name_step(entry)
    end
  end

  def name_step(entry)
    recipient = params[:recipient].to_s.strip
    if recipient.blank?
      entry["recipient"] = nil
      entry["confirmed"] = false
      return ["Add your name first.", :alert]
    end

    entry["recipient"] = recipient[0, 200]
    entry["confirmed"] = false
    ["One more step.", :notice]
  end

  def confirm_step(entry)
    if entry["recipient"].present? && params[:confirmed].to_s == "1"
      entry["confirmed"] = true
      ["You can download it now.", :notice]
    else
      entry["confirmed"] = false
      ["Confirm to continue.", :alert]
    end
  end
end

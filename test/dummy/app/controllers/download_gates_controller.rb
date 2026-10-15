# frozen_string_literal: true

class DownloadGatesController < ApplicationController
  def show
    @recording = gated_recording
    return if performed?
  end

  def update
    recording = gated_recording
    return if performed?

    remember_confirmation(recording)
    @recording = recording
    return render_step(recording) if turbo_frame_request?

    redirect_to download_gate_path(recording_id: recording.id)
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

  def remember_confirmation(recording)
    entries = WorkspaceDownloadGate.entries(session[WorkspaceDownloadGate::SESSION_KEY])
    entry = entries[recording.id.to_s] || {}
    if params[:confirmed].to_s == "1"
      entry["confirmed"] = true
      session[:recording_studio_downloadable_autostart] = recording.id
      flash.now[:notice] = "Your download is ready."
    else
      entry["confirmed"] = false
      flash.now[:alert] = "Check the box to continue."
    end
    entries[recording.id.to_s] = entry
    session[WorkspaceDownloadGate::SESSION_KEY] = entries
    Current.download_gate = entries
  end

  def render_step(recording)
    render partial: "download_gates/frame", locals: { recording: recording }
  end
end

class HomeController < ApplicationController
  def index
    @workspace = Workspace.find_by(name: "Studio Workspace")
    @recording = RecordingStudio::Recording.find_by(recordable: @workspace) if @workspace
    locked = Workspace.find_by(name: "Locked Workspace")
    @locked_recording = RecordingStudio::Recording.find_by(recordable: locked) if locked
    gated = Workspace.find_by(name: WorkspaceDownloadGate::NAME)
    @gated_recording = RecordingStudio::Recording.find_by(recordable: gated) if gated
  end
end

class HomeController < ApplicationController
  def index
    @workspace = Workspace.find_by(name: "Studio Workspace")
    @recording = RecordingStudio::Recording.find_by(recordable: @workspace) if @workspace
  end
end

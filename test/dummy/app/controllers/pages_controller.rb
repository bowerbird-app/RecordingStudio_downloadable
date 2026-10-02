# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @pages = Page.order(:title, :created_at).to_a
    recordings_by_id = page_recordings_by_recordable_id(@pages)

    @page_rows = @pages.map do |page|
      recording = recordings_by_id[page.id]
      {
        title: page.title.presence || "Untitled page",
        description: description_snippet(page.description),
        downloadable: recording&.downloadable? || false,
        recording: recording
      }
    end
  end

  def new
    @page = Page.new
  end

  def create
    @page = Page.new(page_params)
    parent_recording = parent_recording_for_new_page

    unless parent_recording
      flash.now[:alert] = "Seed a workspace (and optional Product Docs folder) before creating pages."
      render :new, status: :unprocessable_entity
      return
    end

    if @page.save
      event = RecordingStudio.record!(
        action: "created",
        recordable: @page,
        root_recording: parent_recording.root_recording || parent_recording,
        parent_recording: parent_recording
      )
      redirect_to recording_studio_attachable.recording_attachment_upload_path(event.recording),
                  notice: "Page created. Upload files to this page recording."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def page_params
    params.require(:page).permit(:title, :description)
  end

  def page_recordings_by_recordable_id(pages)
    RecordingStudio::Recording.where(recordable: pages, trashed_at: nil).index_by(&:recordable_id)
  end

  def description_snippet(text)
    return "—" if text.blank?

    view_context.truncate(text.to_s.squish, length: 80)
  end

  def parent_recording_for_new_page
    folder = Folder.find_by(name: "Product Docs")
    folder_recording = RecordingStudio::Recording.find_by(recordable: folder, trashed_at: nil) if folder
    return folder_recording if folder_recording

    workspace = Workspace.find_by(name: "Studio Workspace") || Workspace.order(:created_at).first
    return if workspace.blank?

    RecordingStudio.root_recording_for(workspace)
  end
end

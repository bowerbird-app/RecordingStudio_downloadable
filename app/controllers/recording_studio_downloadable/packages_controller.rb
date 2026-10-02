# frozen_string_literal: true

module RecordingStudioDownloadable
  class PackagesController < ApplicationController
    def show
      recording = find_recording
      authorize_download!(recording)

      package = recording.downloadable_package
      raise ActiveRecord::RecordNotFound unless recording.downloadable_ready? && package&.archive&.attached?

      blob = package.archive.blob
      filename = download_filename(recording)

      send_data(
        blob.download,
        filename: filename,
        type: "application/zip",
        disposition: "attachment"
      )
    end

    def create
      recording = find_recording
      authorize_download!(recording)

      recording.downloadable_generate!
      recording.reload
      session[:recording_studio_downloadable_autostart] = recording.id
      redirect_back_or_to fallback_location, notice: generate_notice(recording)
    end

    def status
      recording = find_recording
      authorize_download!(recording)

      package = recording.downloadable_package
      render json: {
        state: package&.state || "missing",
        ready: recording.downloadable_ready?,
        failed: package&.failed? || false,
        failure_message: package&.failure_message,
        download_url: recording.downloadable_ready? ? recording.downloadable_download_path : nil
      }
    end

    private

    def download_filename(recording)
      recordable = recording.recordable
      base = recordable.try(:name).presence || recordable.try(:title).presence || recording.id
      "#{Filename.sanitize(base)}.zip"
    end

    def generate_notice(recording)
      if recording.downloadable_empty?
        "Nothing to package."
      elsif recording.downloadable_ready?
        "Download is ready."
      else
        "Building ZIP. The download starts automatically when it is ready."
      end
    end

    def fallback_location
      if respond_to?(:main_app, true)
        main_app.root_path
      else
        "/"
      end
    end
  end
end

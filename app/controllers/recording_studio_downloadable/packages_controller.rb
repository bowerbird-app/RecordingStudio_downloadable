# frozen_string_literal: true

module RecordingStudioDownloadable
  class PackagesController < ApplicationController
    def show
      recording = find_recording
      authorize_download!(recording)

      raise ActiveRecord::RecordNotFound if recording.downloadable_empty?

      unless recording.downloadable_ready?
        recording.downloadable_generate!
        recording.reload
      end

      if recording.downloadable_ready?
        package = recording.downloadable_package
        redirect_to_archive_url!(package.archive.blob, filename: download_filename(recording))
      else
        respond_not_ready(recording)
      end
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
        state: status_state(recording, package),
        ready: recording.downloadable_ready?,
        stale: recording.downloadable_stale?,
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

    def redirect_to_archive_url!(blob, filename:)
      ActiveStorage::Current.url_options ||= {
        protocol: request.protocol,
        host: request.host,
        port: request.port
      }

      redirect_to blob.url(
        expires_in: ActiveStorage.urls_expire_in,
        disposition: :attachment,
        filename: ActiveStorage::Filename.new(filename),
        content_type: "application/zip"
      ), allow_other_host: true
    end

    def respond_not_ready(recording)
      session[:recording_studio_downloadable_autostart] = recording.id

      if iframe_or_async_download_request?
        head :accepted
      else
        redirect_back_or_to fallback_location, notice: generate_notice(recording)
      end
    end

    def iframe_or_async_download_request?
      request.headers["Sec-Fetch-Dest"] == "iframe" ||
        request.xhr? ||
        request.format.json?
    end

    def status_state(recording, package)
      return "stale" if recording.downloadable_stale?

      package&.state || "missing"
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

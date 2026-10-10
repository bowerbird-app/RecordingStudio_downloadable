# frozen_string_literal: true

module RecordingStudioDownloadable
  class PackagesController < ApplicationController
    def show
      recording = find_recording
      authorize_download!(recording)
      throttle_download!(recording)

      raise ActiveRecord::RecordNotFound if recording.downloadable_empty?

      serve_or_prepare!(recording)
    end

    def create
      recording = find_recording
      authorize_download!(recording)
      throttle_download!(recording)

      enqueue_generation_if_granted!(recording)
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
        can_generate: granted_to_generate?(recording),
        download_url: recording.downloadable_ready? ? recording.downloadable_download_path : nil
      }
    end

    private

    def serve_or_prepare!(recording)
      package = recording.downloadable_package
      if serveable_package?(recording, package)
        redirect_to_archive_url!(package.archive.blob, filename: download_filename(recording))
        return
      end

      enqueue_generation_if_granted!(recording)
      recording.reload
      package = recording.downloadable_package

      if serveable_package?(recording, package)
        redirect_to_archive_url!(package.archive.blob, filename: download_filename(recording))
      else
        respond_not_ready(recording)
      end
    end

    def serveable_package?(recording, package)
      return false unless recording.downloadable_ready?
      return false unless fingerprint_matches_for_serve?(recording, package)

      true
    end

    def fingerprint_matches_for_serve?(recording, package)
      return false unless package
      return false unless package.identity_matches?(
        action: downloadable_action_for(recording),
        export_scope: downloadable_export_scope_for(recording)
      )

      recording.downloadable_current_fingerprint_matches?(
        package,
        action: downloadable_action_for(recording),
        export_scope: downloadable_export_scope_for(recording)
      )
    end

    def enqueue_generation_if_granted!(recording)
      return unless granted_to_generate?(recording)

      recording.downloadable_generate!(
        action: downloadable_action_for(recording),
        export_scope: downloadable_export_scope_for(recording),
        force: true
      )
    end

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
        expires_in: archive_url_expires_in,
        disposition: :attachment,
        filename: ActiveStorage::Filename.new(filename),
        content_type: "application/zip"
      ), allow_other_host: true
    end

    def archive_url_expires_in
      configured = ActiveStorage.urls_expire_in
      seconds = configured.respond_to?(:to_i) ? configured.to_i : 0
      return configured if seconds.positive?

      RecordingStudioDownloadable::SIGNED_URL_EXPIRES_IN
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
      return "not_ready" if recording.downloadable_stale? && !granted_to_generate?(recording)
      return "stale" if recording.downloadable_stale?
      return "not_ready" if package.blank? && !granted_to_generate?(recording)

      package&.state || "missing"
    end

    def generate_notice(recording)
      if recording.downloadable_empty?
        Copy.t("notices.empty")
      elsif recording.downloadable_ready?
        Copy.t("notices.ready")
      elsif granted_to_generate?(recording)
        Copy.t("notices.building")
      else
        Copy.t("notices.not_ready")
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

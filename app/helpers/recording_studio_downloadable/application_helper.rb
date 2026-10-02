# frozen_string_literal: true

module RecordingStudioDownloadable
  module ApplicationHelper
    def recording_studio_downloadable_button(recording, **button_options)
      return unless recording.respond_to?(:downloadable?) && recording.downloadable?
      return unless defined?(FlatPack::Button::Component)

      path = downloadable_package_path_for(recording)
      style = button_options.fetch(:style, :primary)
      size = button_options.fetch(:size, :md)
      pending = downloadable_pending?(recording)
      auto_download = downloadable_autostart?(recording) && recording.downloadable_ready?

      control_options = button_options.merge(path: path, style: style, size: size, pending: pending)
      tag.span(data: downloadable_package_poll_data(recording, poll: pending, auto_download: auto_download)) do
        downloadable_button_control(recording, control_options)
      end
    end

    private

    def downloadable_button_control(recording, options)
      path = options.fetch(:path)
      style = options.fetch(:style)
      size = options.fetch(:size)

      if options.fetch(:pending)
        render FlatPack::Button::Component.new(
          text: options.fetch(:preparing_text, "Preparing…"),
          style: options.fetch(:style, :secondary),
          size: size
        )
      elsif recording.downloadable_package&.failed?
        render FlatPack::Button::Component.new(
          text: options.fetch(:retry_text, "Retry download"),
          style: style,
          size: size,
          href: path,
          title: recording.downloadable_package.failure_message.presence,
          data: { turbo_method: :post }
        )
      elsif recording.downloadable_ready?
        render FlatPack::Button::Component.new(
          text: options.fetch(:ready_text, "Download"),
          style: style,
          size: size,
          href: path,
          data: { turbo: false }
        )
      else
        render FlatPack::Button::Component.new(
          text: options.fetch(:generate_text, "Download"),
          style: style,
          size: size,
          href: path,
          data: { turbo_method: :post }
        )
      end
    end

    def downloadable_pending?(recording)
      recording.downloadable_package&.processing? || recording.downloadable_package&.pending?
    end

    def downloadable_package_path_for(recording)
      downloadable_routes.recording_package_path(recording)
    end

    def downloadable_package_status_path_for(recording)
      downloadable_routes.recording_package_status_path(recording)
    end

    def downloadable_autostart?(recording)
      return false unless respond_to?(:session)

      id = session[:recording_studio_downloadable_autostart]
      return false unless id.to_s == recording.id.to_s

      session.delete(:recording_studio_downloadable_autostart)
      true
    end

    def downloadable_package_poll_data(recording, poll:, auto_download:)
      {
        controller: "recording-studio-downloadable--package",
        action: "click->recording-studio-downloadable--package#startDownload",
        "recording-studio-downloadable--package-status-url-value": downloadable_package_status_path_for(recording),
        "recording-studio-downloadable--package-download-url-value": downloadable_package_path_for(recording),
        "recording-studio-downloadable--package-poll-value": poll,
        "recording-studio-downloadable--package-auto-download-value": auto_download
      }
    end

    def downloadable_routes
      if respond_to?(:recording_studio_downloadable, true)
        recording_studio_downloadable
      else
        RecordingStudioDownloadable::Engine.routes.url_helpers
      end
    end
  end
end

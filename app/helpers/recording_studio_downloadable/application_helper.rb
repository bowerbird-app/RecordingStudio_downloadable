# frozen_string_literal: true

module RecordingStudioDownloadable
  module ApplicationHelper
    def recording_studio_downloadable_button(recording, **button_options)
      return unless recording.respond_to?(:downloadable?) && recording.downloadable?
      return unless defined?(FlatPack::Button::Component)

      path = downloadable_package_path_for(recording)
      style = button_options.fetch(:style, :primary)
      size = button_options.fetch(:size, :md)

      if recording.downloadable_ready?
        ready_button = render FlatPack::Button::Component.new(
          text: button_options.fetch(:ready_text, "Download"),
          style: style,
          size: size,
          href: path,
          data: { turbo: false }
        )
        return ready_button unless downloadable_autostart?(recording)

        tag.span(data: downloadable_package_poll_data(recording, poll: false, auto_download: true)) do
          ready_button
        end
      elsif recording.downloadable_package&.failed?
        render FlatPack::Button::Component.new(
          text: button_options.fetch(:retry_text, "Retry download"),
          style: style,
          size: size,
          href: path,
          title: recording.downloadable_package.failure_message.presence,
          data: { turbo_method: :post }
        )
      elsif recording.downloadable_package&.processing? || recording.downloadable_package&.pending?
        tag.span(data: downloadable_package_poll_data(recording, poll: true, auto_download: false)) do
          render FlatPack::Button::Component.new(
            text: button_options.fetch(:preparing_text, "Preparing…"),
            style: button_options.fetch(:style, :secondary),
            size: size
          )
        end
      else
        render FlatPack::Button::Component.new(
          text: button_options.fetch(:generate_text, "Download"),
          style: style,
          size: size,
          href: path,
          data: { turbo_method: :post }
        )
      end
    end

    private

    def downloadable_package_path_for(recording)
      downloadable_routes.recording_package_path(recording)
    end

    def downloadable_package_status_path_for(recording)
      downloadable_routes.recording_package_status_path(recording)
    end

    def downloadable_autostart?(recording)
      flash[:recording_studio_downloadable_autostart].to_s == recording.id.to_s
    end

    def downloadable_package_poll_data(recording, poll:, auto_download:)
      {
        controller: "recording-studio-downloadable--package",
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

# frozen_string_literal: true

module RecordingStudioDownloadable
  module ApplicationHelper
    def recording_studio_downloadable_button(recording, **button_options)
      return unless recording.respond_to?(:downloadable?) && recording.downloadable?
      return unless defined?(FlatPack::Button::Component)

      path = downloadable_package_path_for(recording)

      if recording.downloadable_ready?
        render FlatPack::Button::Component.new(
          text: button_options.fetch(:ready_text, "Download"),
          style: button_options.fetch(:style, :primary),
          size: button_options.fetch(:size, :md),
          url: path
        )
      elsif recording.downloadable_package&.processing? || recording.downloadable_package&.pending?
        render FlatPack::Button::Component.new(
          text: button_options.fetch(:preparing_text, "Preparing…"),
          style: button_options.fetch(:style, :secondary),
          size: button_options.fetch(:size, :md)
        )
      else
        render FlatPack::Button::Component.new(
          text: button_options.fetch(:generate_text, "Download"),
          style: button_options.fetch(:style, :primary),
          size: button_options.fetch(:size, :md),
          url: path,
          data: { turbo_method: :post }
        )
      end
    end

    private

    def downloadable_package_path_for(recording)
      downloadable_routes.recording_package_path(recording)
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

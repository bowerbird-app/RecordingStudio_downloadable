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
      can_generate = downloadable_can_generate?(recording)

      control_options = button_options.merge(
        path: path,
        style: style,
        size: size,
        pending: pending,
        can_generate: can_generate
      )
      tag.span(
        data: downloadable_package_poll_data(
          recording,
          poll: pending,
          auto_download: auto_download,
          can_generate: can_generate
        )
      ) do
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
          text: options.fetch(:preparing_text, Copy.t("buttons.preparing")),
          style: options.fetch(:style, :secondary),
          size: size
        )
      elsif recording.downloadable_package&.failed?
        render FlatPack::Button::Component.new(
          text: options.fetch(:retry_text, Copy.t("buttons.retry")),
          style: style,
          size: size,
          href: path,
          title: recording.downloadable_package.failure_message.presence,
          data: { turbo_method: :post }
        )
      elsif recording.downloadable_ready?
        render FlatPack::Button::Component.new(
          text: options.fetch(:ready_text, Copy.t("buttons.download")),
          style: style,
          size: size,
          href: path,
          data: { turbo: false }
        )
      else
        render FlatPack::Button::Component.new(
          text: options.fetch(:generate_text, Copy.t("buttons.download")),
          style: style,
          size: size,
          href: path,
          data: options.fetch(:can_generate, true) ? { turbo_method: :post } : { turbo: false }
        )
      end
    end

    def downloadable_pending?(recording)
      recording.downloadable_package&.processing? || recording.downloadable_package&.pending?
    end

    def downloadable_can_generate?(recording)
      return false unless recording.respond_to?(:downloadable_action)

      RecordingStudioDownloadable::Authorization.allowed?(
        action: recording.downloadable_action,
        actor: downloadable_view_actor,
        recording: recording
      )
    end

    def downloadable_view_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor) && Current.actor
      return current_user if respond_to?(:current_user, true)

      nil
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

    def downloadable_package_poll_data(recording, poll:, auto_download:, can_generate:)
      {
        controller: "recording-studio-downloadable--package",
        action: "click->recording-studio-downloadable--package#startDownload",
        "recording-studio-downloadable--package-status-url-value": downloadable_package_status_path_for(recording),
        "recording-studio-downloadable--package-download-url-value": downloadable_package_path_for(recording),
        "recording-studio-downloadable--package-poll-value": poll,
        "recording-studio-downloadable--package-auto-download-value": auto_download,
        "recording-studio-downloadable--package-can-generate-value": can_generate,
        "recording-studio-downloadable--package-ready-text-value": Copy.t("buttons.download"),
        "recording-studio-downloadable--package-preparing-text-value": Copy.t("buttons.preparing"),
        "recording-studio-downloadable--package-retry-text-value": Copy.t("buttons.retry"),
        "recording-studio-downloadable--package-not-ready-text-value": Copy.t("notices.not_ready"),
        "recording-studio-downloadable--package-timeout-text-value": Copy.t("notices.timeout")
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

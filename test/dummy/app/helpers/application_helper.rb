# frozen_string_literal: true

module ApplicationHelper
  def dummy_sidebar_item(text:, href:, icon:)
    render FlatPack::Sidebar::Item::Component.new(
      text: text,
      href: href,
      icon: icon,
      active: current_page?(href)
    )
  end

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end

  def dummy_page_row_actions(recording)
    return "No recording" unless recording

    parts = [
      link_to("Upload", recording_studio_attachable.recording_attachment_upload_path(recording), class: "underline"),
      link_to("Attachments", recording_studio_attachable.recording_attachments_path(recording), class: "underline")
    ]

    if recording.downloadable?
      download_options = { class: "underline" }
      download_options[:data] = { turbo_method: :post } unless recording.downloadable_ready?
      parts << link_to("Download", recording.downloadable_download_path, download_options)
    end

    safe_join(parts, " · ".html_safe)
  end
end

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

  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    content_for(:title, title)
    content_for(:subtitle, subtitle) if subtitle.present?
    return if back_url.blank?

    flat_pack_page_nav(
      round: true,
      style: :default,
      back_href: back_url,
      back_tooltip: back_label
    )
  end

  def dummy_page_row_actions(recording)
    return "No recording" unless recording

    parts = [
      link_to("Upload", recording_studio_attachable.recording_attachment_upload_path(recording), class: "underline"),
      link_to("Attachments", recording_studio_attachable.recording_attachments_path(recording), class: "underline")
    ]

    if recording.downloadable?
      parts << recording_studio_downloadable_button(recording, style: :ghost, size: :sm)
      parts << recording_studio_downloadable_history_link(recording, style: :ghost, size: :sm)
    end

    safe_join(parts, " · ".html_safe)
  end

  def dummy_press_kit_row_actions(press_kit, recording)
    parts = []
    if recording
      parts << link_to(
        "Upload",
        recording_studio_attachable.recording_attachment_upload_path(recording),
        class: "underline"
      )
      parts << link_to(
        "Attachments",
        recording_studio_attachable.recording_attachments_path(recording),
        class: "underline"
      )
      if recording.downloadable?
        parts << recording_studio_downloadable_button(recording, style: :ghost, size: :sm)
        parts << recording_studio_downloadable_history_link(recording, style: :ghost, size: :sm)
      end
    end
    parts << link_to("Edit", edit_press_kit_path(press_kit), class: "underline")
    safe_join(parts, " · ".html_safe)
  end
end

# frozen_string_literal: true

require_relative "../downloadable_test_helper"

class DownloadableButtonHelperTest < ActionView::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper
  include RecordingStudioDownloadable::ApplicationHelper

  setup do
    @actor = User.create!(email: "btn-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @actor)
    Current.actor = @actor if defined?(Current)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "pending package button polls status instead of linking the zip" do
    @recording.downloadable_generate!
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "recording-studio-downloadable--package"
    assert_match(/<span>Preparing/, html)
    assert_includes html, "package/status"
    refute_includes html, "data-turbo-method"
  end

  test "failed package button is a retry post" do
    RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      format: "zip",
      state: "failed",
      failure_message: "Source set is empty"
    )
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Retry download"
    assert_includes html, "turbo-method"
    assert_includes html, "Source set is empty"
    refute_match(/<span>Preparing/, html)
  end

  test "failed package button title shows persisted failure message as-is" do
    RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      format: "zip",
      action: @recording.downloadable_action.to_s,
      export_scope: "public",
      state: "failed",
      failure_message: RecordingStudioDownloadable::Copy::EMPTY_NOTICE
    )
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Retry download"
    assert_includes html, "Nothing to package."
  end

  test "stimulus data attributes pass english defaults for js fallbacks" do
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, 'recording-studio-downloadable--package-ready-text-value="Download"'
    assert_includes html, "package-preparing-text-value=\"Preparing…"
    assert_includes html, 'package-retry-text-value="Retry download"'
    assert_includes html, 'package-not-ready-text-value="This download is not ready yet."'
    assert_includes html, "package-timeout-text-value="
  end

  test "ready package button is a turbo-free zip get" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Download"
    assert_includes html, "data-turbo=\"false\""
    assert_includes html, "recording-studio-downloadable--package"
    assert_includes html, "startDownload"
    refute_match(/<span>Preparing/, html)
    refute_includes html, "package-poll-value=\"true\""
  end

  test "stale ready-state package uses generate post not a raw zip get" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @actor)
    html = recording_studio_downloadable_button(@recording.reload)

    assert_includes html, "Download"
    assert_includes html, "turbo-method"
    assert_includes html, "startDownload"
    refute_match(/<span>Preparing/, html)
  end

  test "anonymous visitors see the registered fallback instead of a generate post" do
    Current.actor = nil
    html = recording_studio_downloadable_button(@recording.reload).to_s

    assert_includes html, "Ask for access"
    refute_includes html, "recording-studio-downloadable--package"
    refute_includes html, "turbo-method"
  end

  test "denied download renders nothing when no fallback is registered" do
    with_denied_components({}) do
      Current.actor = nil
      html = recording_studio_downloadable_button(@recording.reload).to_s

      assert_equal "", html
    end
  end

  test "denied download renders the component registered for that action" do
    kit = PressKit.create!(name: "Denied kit", description: "Nope", credits: "Nobody")
    kit_recording = RecordingStudio.record!(
      action: "created",
      recordable: kit,
      root_recording: @recording,
      parent_recording: @recording,
      actor: @actor
    ).recording
    with_denied_components(
      "workspaces.download": WorkspaceDeniedComponent,
      "press_kits.download": KitDeniedComponent
    ) do
      Current.actor = nil
      workspace_html = recording_studio_downloadable_button(@recording.reload).to_s
      kit_html = recording_studio_downloadable_button(kit_recording).to_s

      assert_includes workspace_html, "workspace-denied:workspaces.download"
      assert_includes kit_html, "kit-denied:press_kits.download"
      refute_includes workspace_html, "kit-denied"
      refute_includes kit_html, "workspace-denied"
    end
  end

  test "allowed download still renders the button when a fallback is registered" do
    html = recording_studio_downloadable_button(@recording.reload).to_s

    assert_includes html, "Download"
    refute_includes html, "Ask for access"
  end

  test "history link is shown to editors and hidden from viewers" do
    html = recording_studio_downloadable_history_link(@recording).to_s

    assert_includes html, "History"
    assert_includes html, "download_logs"
    assert_includes html, @recording.id

    viewer = User.create!(email: "viewer-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    other = create_workspace_recording
    grant_download_access!(other, @actor)
    grant_role!(other, viewer, :view)
    Current.actor = viewer
    assert_nil recording_studio_downloadable_history_link(other)
  end

  test "anonymous visitors get a generate post when the audience is public" do
    audience = {
      allowed: %i[public granted],
      default: :public,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
    with_action_audience(:"workspaces.download", audience) do
      Current.actor = nil
      html = recording_studio_downloadable_button(@recording.reload)

      assert_includes html, "Download"
      assert_includes html, "turbo-method"
      assert_includes html, "can-generate-value=\"true\""
    end
  end

  private

  def with_denied_components(mapping)
    config = RecordingStudioDownloadable.configuration
    previous = config.access_denied_components.dup
    config.access_denied_components.clear
    mapping.each do |action, component|
      config.register_access_denied_component(action, component)
    end
    yield
  ensure
    config.access_denied_components.replace(previous)
  end

  def grant_role!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @actor
    )
    raise result.error if result.failure?
  end
end

class WorkspaceDeniedComponent < ViewComponent::Base
  def initialize(recording:, actor:, action:)
    super()
    @action = action
    @recording = recording
    @actor = actor
  end

  def call
    "workspace-denied:#{@action}".html_safe
  end
end

class KitDeniedComponent < ViewComponent::Base
  def initialize(recording:, actor:, action:)
    super()
    @action = action
    @recording = recording
    @actor = actor
  end

  def call
    "kit-denied:#{@action}".html_safe
  end
end

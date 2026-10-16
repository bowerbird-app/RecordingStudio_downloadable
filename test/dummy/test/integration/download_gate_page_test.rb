# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DownloadGatePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "gate-page-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @workspace = Workspace.find_or_create_by!(name: WorkspaceDownloadGate::NAME)
    @recording = RecordingStudio.root_recording_for(@workspace)
    grant_studio_download_access!(@recording, @user)
    Current.actor = @user if defined?(Current)
    attach_notes! if @recording.downloadable_files.empty?
    sign_in @user
  end

  test "the dummy gate button opens a confirmation modal then logs a ready download" do
    get download_gate_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Gated Download"
    assert_includes response.body, ">Download<"
    refute_includes response.body, "Before you download"
    assert_includes response.body, "Send me the ZIP"
    assert_includes response.body, %(data-modal-id="#{WorkspaceDownloadGate.modal_id(@recording)}")
    assert_includes response.body, "p-[var(--card-padding-lg)]"
    assert_includes response.body, "gap-6"
    refute_includes response.body, "recording-studio-downloadable--package"
    refute_includes response.body, "Your name"

    assert_no_difference -> { logs.count } do
      patch frame_path, params: { recording_id: @recording.id }, headers: frame_headers
    end
    assert_includes response.body, "Check the box to continue."
    refute_includes response.body, "Your download is ready."

    assert_no_difference -> { logs.count } do
      get recording_studio_downloadable.recording_package_path(@recording)
    end
    assert_redirected_to "/download_gate?recording_id=#{@recording.id}"

    patch frame_path, params: { recording_id: @recording.id, confirmed: "1" }, headers: frame_headers

    assert_response :success
    assert_includes response.body, "Getting your files together."
    assert_includes response.body, "role=\"progressbar\""
    assert_includes response.body, "data-downloadable-progress"
    assert_includes response.body, "data-downloadable-progress-label"
    assert_includes response.body, "text-lg"
    refute_includes response.body, "text-sm"
    refute_includes response.body, "Ready."
    assert_includes response.body, "Download started"
    refute_includes response.body, "Download started."
    refute_includes response.body, "Your ZIP is on its way."
    refute_includes response.body, "Before you download"
    refute_includes response.body, "role=\"alert\""
    assert_includes response.body, "fp-empty-state"
    assert_includes response.body, "items-center"
    assert_includes response.body, 'data-flat-pack--icon-name-value="check-circle"'
    assert_includes response.body, 'data-flat-pack--icon-variant-value="solid"'
    assert_includes response.body, "text-[var(--color-success-background-color)]"
    assert_includes response.body, "data-downloadable-started"
    assert_includes response.body, "hidden"
    assert_includes response.body, "gap-6"
    assert_includes response.body, "recording-studio-downloadable--package"
    assert_includes response.body, 'auto-download-value="true"'
    refute_includes response.body, ">Download<"
    refute_includes response.body, "Your download is ready."

    perform_enqueued_jobs { @recording.downloadable_generate! }

    assert_difference -> { logs.count }, 1 do
      get recording_studio_downloadable.recording_package_path(@recording)
    end
    assert_equal({ "confirmed" => true }, logs.order(:created_at).last.metadata)

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_equal 2, logs.count

    get recording_studio_admin_admin.screen_table_path("download_logs", recording_id: @recording.id),
        headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, @user.email
    refute_includes response.body, "Send me the ZIP"
  end

  test "a full page confirm returns to the download button" do
    patch "/download_gate", params: { recording_id: @recording.id, confirmed: "1" }

    assert_redirected_to "/download_gate?recording_id=#{@recording.id}"
    follow_redirect!
    assert_includes response.body, "recording-studio-downloadable--package"
    assert_includes response.body, ">Download<"
    refute_includes response.body, "Send me the ZIP"
  end

  test "someone without access cannot open the gate form" do
    outsider = User.create!(email: "gate-outsider-#{SecureRandom.hex(4)}@example.com", password: "Password",
                            password_confirmation: "Password")
    sign_in outsider

    get download_gate_path(recording_id: @recording.id)

    assert_response :forbidden
  end

  private

  def frame_path
    "/download_gate"
  end

  def frame_headers
    { "Turbo-Frame" => WorkspaceDownloadGate.frame_id(@recording) }
  end

  def logs
    RecordingStudioDownloadable::DownloadLog.where(recording_id: @recording.id)
  end

  def attach_notes!
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("notes for the gated zip"),
      filename: "notes.txt",
      content_type: "text/plain"
    )
    @recording.record_attachment_upload(signed_blob_id: blob.signed_id, actor: @user, name: "notes")
  end
end

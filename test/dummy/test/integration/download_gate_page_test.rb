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

  test "the dummy gate form blocks then logs metadata the history screen hides" do
    get download_gate_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Before you download"
    assert_includes response.body, "Your name"
    refute_includes response.body, "recording-studio-downloadable--package"

    patch download_gate_path, params: { recording_id: @recording.id, step: "name", recipient: " " }
    follow_redirect!
    assert_includes response.body, "Add your name first."

    patch download_gate_path, params: {
      recording_id: @recording.id, step: "name", recipient: "zigzag-recipient"
    }
    follow_redirect!
    assert_includes response.body, "Send me the ZIP"
    assert_includes response.body, "For zigzag-recipient."

    assert_no_difference -> { logs.count } do
      get recording_studio_downloadable.recording_package_path(@recording)
    end
    assert_redirected_to "/download_gate?recording_id=#{@recording.id}"

    patch "/download_gate", params: { recording_id: @recording.id, step: "confirm", confirmed: "1" }
    follow_redirect!
    assert_includes response.body, "Download"
    assert_includes response.body, "recording-studio-downloadable--package"

    perform_enqueued_jobs { @recording.downloadable_generate! }

    assert_difference -> { logs.count }, 1 do
      get recording_studio_downloadable.recording_package_path(@recording)
    end
    assert_equal "zigzag-recipient", logs.order(:created_at).last.metadata["recipient"]
    assert_equal true, logs.order(:created_at).last.metadata["confirmed"]

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_equal 2, logs.count

    get recording_studio_admin_admin.screen_table_path("download_logs", recording_id: @recording.id),
        headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, @user.email
    refute_includes response.body, "zigzag-recipient"
  end

  test "someone without access cannot open the gate form" do
    outsider = User.create!(email: "gate-outsider-#{SecureRandom.hex(4)}@example.com", password: "Password",
                            password_confirmation: "Password")
    sign_in outsider

    get download_gate_path(recording_id: @recording.id)

    assert_response :forbidden
  end

  private

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

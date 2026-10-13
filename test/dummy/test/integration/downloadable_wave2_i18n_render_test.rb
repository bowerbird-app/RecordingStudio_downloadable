# frozen_string_literal: true

require_relative "../test_helper"
require "devise/test/integration_helpers"

# Render-level literal-English asserts for wave 2 non-view copy.
# Does not rewrite existing tests to expect HOST strings.
class DownloadableWave2I18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.find_or_create_by!(email: "wave2-i18n@example.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @recording = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @recording, actor: @user)
    Current.actor = @user if defined?(Current)
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "home download button renders literal english labels and stimulus values" do
    get "/"

    assert_response :success
    assert_includes response.body, "Download"
    assert_includes response.body, 'recording-studio-downloadable--package-ready-text-value="Download"'
    assert_includes response.body, "recording-studio-downloadable--package-preparing-text-value=\"Preparing…"
    assert_includes response.body, 'recording-studio-downloadable--package-retry-text-value="Retry download"'
    assert_includes response.body, 'recording-studio-downloadable--package-not-ready-text-value="This download is not ready yet."'
    # Boot-order host override owns notices.timeout; visible button stays gem English.
    assert_includes response.body, "HOST Download is taking too long. Retry."
    refute_includes response.body, "HOST Download\""
  end

  test "create flash renders building notice in literal english" do
    attach_text!(@recording, filename: "wave2.txt", contents: "wave2")

    post recording_studio_downloadable.recording_package_path(@recording),
         headers: { "HTTP_REFERER" => "http://www.example.com/" }

    assert_response :redirect
    assert_equal(
      "Building ZIP. The download starts automatically when it is ready.",
      flash[:notice]
    )
  end

  test "ready package create flash renders ready notice in literal english" do
    attach_text!(@recording, filename: "ready.txt", contents: "ready")
    perform_enqueued_jobs { @recording.downloadable_generate! }

    post recording_studio_downloadable.recording_package_path(@recording),
         headers: { "HTTP_REFERER" => "http://www.example.com/" }

    assert_response :redirect
    assert_equal "Download is ready.", flash[:notice]
  end

  private

  def attach_text!(parent_recording, filename:, contents:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(contents),
      filename: filename,
      content_type: "text/plain"
    )
    parent_recording.record_attachment_upload(
      signed_blob_id: blob.signed_id,
      actor: @user,
      name: File.basename(filename, ".*").presence || filename
    )
  end
end

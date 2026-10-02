# frozen_string_literal: true

require_relative "downloadable_test_helper"

class PackagesControllerTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "dl-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user
  end

  test "authorized download redirects to a short-lived blob url without buffering the zip" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    location = response.redirect_url
    assert_predicate location, :present?
    refute_match(%r{/recording_studio_downloadable/recordings/.+/package\z}, URI.parse(location).path)
    assert_match(%r{attachment|rails/active_storage|X-Amz-Signature|response-content-disposition}i, location)

    follow_redirect!

    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
    assert_match(/\.zip/, response.headers["Content-Disposition"].to_s)

    entries = {}
    Zip::File.open_buffer(response.body) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    assert_equal "packed", entries["pack.txt"]
  end

  test "download is not found when the package is missing or not ready" do
    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :not_found
  end

  test "denied actor cannot download a ready package" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    sign_in @other

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
    assert_nil response.redirect_url
  end

  test "empty recording download is not found" do
    empty = create_workspace_recording
    grant_download_access!(empty, @user)

    get recording_studio_downloadable.recording_package_path(empty)

    assert_response :not_found
  end

  test "create enqueues generation for an authorized actor" do
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      post recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_response :redirect
  end

  test "status returns json for an authorized actor and forbids others" do
    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "missing", payload["state"]
    assert_equal false, payload["ready"]
    assert_equal false, payload["failed"]
    assert_nil payload["download_url"]

    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "ready", payload["state"]
    assert_equal true, payload["ready"]
    assert_equal recording_studio_downloadable.recording_package_path(@recording), payload["download_url"]

    sign_in @other
    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :forbidden
  end

  test "status reports failed packages without sending a zip" do
    package = RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      format: "zip",
      state: "failed",
      failure_message: "Source set is empty"
    )

    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal package.state, payload["state"]
    assert_equal true, payload["failed"]
    assert_equal "Source set is empty", payload["failure_message"]
    assert_equal false, payload["ready"]
    assert_nil payload["download_url"]
  end
end

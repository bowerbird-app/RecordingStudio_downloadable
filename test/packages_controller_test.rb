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

  teardown do
    uninstall_workspace_manifest!
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

  test "authorized download still redirects when urls_expire_in is 0" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    previous = ActiveStorage.urls_expire_in
    ActiveStorage.urls_expire_in = 0

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    location = response.redirect_url
    assert_predicate location, :present?
    refute_match(%r{/recording_studio_downloadable/recordings/.+/package\z}, URI.parse(location).path)
    assert_match(%r{attachment|rails/active_storage|X-Amz-Signature|response-content-disposition}i, location)

    follow_redirect!

    assert_response :success
    entries = {}
    Zip::File.open_buffer(response.body) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    assert_equal "packed", entries["pack.txt"]
  ensure
    ActiveStorage.urls_expire_in = previous
  end

  test "download is not found when the recording has no files" do
    empty = create_workspace_recording
    grant_download_access!(empty, @user)

    get recording_studio_downloadable.recording_package_path(empty)

    assert_response :not_found
  end

  test "missing package GET with files enqueues generate instead of 404" do
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/pages" }
    end

    assert_response :redirect
    assert_redirected_to "http://www.example.com/pages"
  end

  test "stale package after new attachments regenerates then redirects to a current zip" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)

    refute @recording.reload.downloadable_ready?
    assert @recording.downloadable_stale?

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/pages" }
    end

    assert_response :redirect
    assert_redirected_to "http://www.example.com/pages"

    perform_enqueued_jobs
    assert @recording.reload.downloadable_ready?

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    follow_redirect!
    assert_response :success

    entries = {}
    Zip::File.open_buffer(response.body) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    assert_equal "packed", entries["pack.txt"]
    assert_equal "more", entries["extra.txt"]
  end

  test "stale package iframe GET returns accepted and enqueues regenerate" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "Sec-Fetch-Dest" => "iframe" }
    end

    assert_response :accepted
  end

  test "denied actor cannot download a stale package" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)
    sign_in @other

    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_response :forbidden
    assert_nil response.redirect_url
  end

  test "denied actor cannot download a ready package" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    sign_in @other

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
    assert_nil response.redirect_url
  end

  test "create enqueues generation for an authorized actor" do
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      post recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_response :redirect
  end

  test "create enqueues regeneration when the package is stale" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)

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
    assert_equal false, payload["stale"]
    assert_equal false, payload["failed"]
    assert_nil payload["download_url"]

    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "ready", payload["state"]
    assert_equal true, payload["ready"]
    assert_equal false, payload["stale"]
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
    assert_equal false, payload["stale"]
    assert_equal "Source set is empty", payload["failure_message"]
    assert_equal false, payload["ready"]
    assert_nil payload["download_url"]
  end

  test "status reports stale after new attachments" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)

    get recording_studio_downloadable.recording_package_status_path(@recording), as: :json

    assert_response :success
    payload = response.parsed_body
    assert_equal "stale", payload["state"]
    assert_equal true, payload["stale"]
    assert_equal false, payload["ready"]
    assert_nil payload["download_url"]
  end

  test "empty manifest download is not found like empty attachments" do
    empty = create_workspace_recording
    grant_download_access!(empty, @user)
    install_workspace_manifest!

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      get recording_studio_downloadable.recording_package_path(empty)

      assert_response :not_found
    end
  end

  test "denied actor cannot download a ready manifest package" do
    install_workspace_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: "Jane")
    )

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      perform_enqueued_jobs { @recording.downloadable_generate! }
      sign_in @other

      get recording_studio_downloadable.recording_package_path(@recording)

      assert_response :forbidden
      assert_nil response.redirect_url
    end
  end
end

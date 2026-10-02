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

  test "download serves a ready zip with attachment disposition" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
    assert_match(/\.zip/, response.headers["Content-Disposition"].to_s)
    refute_match(%r{/rails/active_storage}, response.headers["Location"].to_s)
    refute_match(%r{/rails/active_storage}, response.body.to_s)

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
end

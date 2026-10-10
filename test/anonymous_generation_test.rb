# frozen_string_literal: true

require_relative "downloadable_test_helper"

class AnonymousGenerationTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "anon-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    configure_public_download!
  end

  teardown do
    restore_download_audience!
  end

  test "anonymous authorized show create and status enqueue exactly once when missing" do
    sign_out @user

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/" }
      assert_response :redirect

      post recording_studio_downloadable.recording_package_path(@recording)
      assert_response :redirect

      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      assert_response :success
    end

    payload = response.parsed_body
    assert_equal "pending", payload["state"]
    assert_equal false, payload["ready"]
    assert_equal true, payload["can_generate"]
    assert_nil payload["download_url"]
    assert @recording.reload.downloadable_package.pending?
  end

  test "anonymous authorized status polling enqueues a stale package once" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)
    sign_out @user

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
    end

    assert_response :success
    payload = response.parsed_body
    assert_equal false, payload["ready"]
    assert_equal true, payload["can_generate"]
    assert_nil payload["download_url"]
    assert_includes %w[pending processing], @recording.reload.downloadable_package.state
  end

  test "anonymous show of a stale package does not serve the old zip and enqueues a rebuild" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)
    sign_out @user

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/" }
    end

    assert_response :redirect
    refute_match(/active_storage|X-Amz-Signature/i, response.redirect_url.to_s)
    refute @recording.reload.downloadable_ready?
  end

  test "unauthorized anonymous never enqueues a build" do
    RecordingStudioAccessible.configuration.action_audiences[:"workspaces.download"] = {
      allowed: %i[granted],
      default: :granted,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
    sign_out @user

    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording)
      assert_response :forbidden

      post recording_studio_downloadable.recording_package_path(@recording)
      assert_response :forbidden

      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      assert_response :forbidden
    end

    assert_nil @recording.reload.downloadable_package
  end

  test "anonymous show of a current public package redirects to the signed zip" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    sign_out @user

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
  end

  test "concurrent authorized requests share one in-flight build" do
    sign_out @user

    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/" }
      post recording_studio_downloadable.recording_package_path(@recording)
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
    end

    assert_equal 1, RecordingStudioDownloadable::Package.where(recording: @recording).count
  end

  test "revoked actor cannot download a ready package" do
    RecordingStudioAccessible.configuration.action_audiences[:"workspaces.download"] = {
      allowed: %i[granted],
      default: :granted,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }

    viewer = User.create!(email: "viewer-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    access = RecordingStudioAccessible::Services::GrantRecordingAccess.call(
      recording: @recording,
      actor: viewer,
      role: :view,
      manager_actor: @user
    ).value!

    perform_enqueued_jobs { @recording.downloadable_generate! }

    RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
      recording: @recording,
      access_recording: access,
      manager_actor: @user
    )

    sign_in viewer
    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
    assert_nil response.redirect_url
  end

  private

  def configure_public_download!
    @previous_audiences = RecordingStudioAccessible.configuration.action_audiences.to_h
    RecordingStudioAccessible.configuration.action_audiences[:"workspaces.download"] = {
      allowed: %i[public granted],
      default: :public,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
  end

  def restore_download_audience!
    RecordingStudioAccessible.configuration.action_audiences.replace(@previous_audiences)
  end
end

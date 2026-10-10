# frozen_string_literal: true

require_relative "downloadable_test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    @previous_limits = RecordingStudioDownloadable.configuration.rate_limits.deep_dup
    @previous_concurrent = RecordingStudioDownloadable.configuration.max_concurrent_builds
    @user = User.create!(email: "rate-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user
  end

  teardown do
    RecordingStudioDownloadable.configuration.rate_limits = @previous_limits
    RecordingStudioDownloadable.configuration.max_concurrent_builds = @previous_concurrent
    Rails.cache.clear
  end

  test "rate limits per ip actor and recording are keyed by action" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 1, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 100, period: 1.minute }
    }

    get recording_studio_downloadable.recording_package_path(@recording),
        headers: { "HTTP_REFERER" => "http://www.example.com/" }
    assert_response :redirect

    get recording_studio_downloadable.recording_package_path(@recording),
        headers: { "HTTP_REFERER" => "http://www.example.com/" }
    assert_response :too_many_requests
  end

  test "actor rate limit is independent of ip when actor bucket is exhausted" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 100, period: 1.minute },
      actor: { limit: 1, period: 1.minute },
      recording: { limit: 100, period: 1.minute }
    }

    get recording_studio_downloadable.recording_package_path(@recording)
    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :too_many_requests
  end

  test "recording rate limit does not consume another recording's budget" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 100, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 1, period: 1.minute }
    }
    other = create_workspace_recording
    grant_download_access!(other, @user)
    attach_file!(other, filename: "b.txt", contents: "bbb", actor: @user)

    get recording_studio_downloadable.recording_package_path(@recording)
    get recording_studio_downloadable.recording_package_path(@recording)
    assert_response :too_many_requests

    get recording_studio_downloadable.recording_package_path(other),
        headers: { "HTTP_REFERER" => "http://www.example.com/" }
    assert_response :redirect
  end

  test "concurrent build cap is per action across recordings" do
    RecordingStudioDownloadable.configuration.max_concurrent_builds = 1
    RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      action: @recording.downloadable_action.to_s,
      export_scope: "public",
      format: "zip",
      state: "processing",
      source_fingerprint: "busy"
    )

    other = create_workspace_recording
    grant_download_access!(other, @user)
    attach_file!(other, filename: "b.txt", contents: "bbb", actor: @user)

    error = assert_raises(RecordingStudioDownloadable::ConcurrentBuildLimitError) do
      other.downloadable_generate!
    end

    assert_includes error.message, "already being built"
    assert_nil other.reload.downloadable_package
  end
end

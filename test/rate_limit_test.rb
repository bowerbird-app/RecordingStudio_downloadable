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
    @previous_cache = RecordingStudioDownloadable.configuration.cache
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
    RecordingStudioDownloadable.configuration.cache = @previous_cache
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

  test "rate limits still apply to authorized anonymous downloads" do
    previous = RecordingStudioAccessible.configuration.action_audiences.to_h
    RecordingStudioAccessible.configuration.action_audiences[:"workspaces.download"] = {
      allowed: %i[public granted],
      default: :public,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 1, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 100, period: 1.minute }
    }
    sign_out @user

    get recording_studio_downloadable.recording_package_path(@recording),
        headers: { "HTTP_REFERER" => "http://www.example.com/" }
    assert_response :redirect

    get recording_studio_downloadable.recording_package_path(@recording),
        headers: { "HTTP_REFERER" => "http://www.example.com/" }
    assert_response :too_many_requests
  ensure
    RecordingStudioAccessible.configuration.action_audiences.replace(previous)
  end

  test "blank or nil bucket keys skip throttling for that bucket" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 100, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 1, period: 1.minute }
    }

    assert RecordingStudioDownloadable::RateLimiter.send(
      :throttle_bucket!, :recording, key: nil, action: "workspaces.download", limit: 1, period: 60
    )
    assert RecordingStudioDownloadable::RateLimiter.send(
      :throttle_bucket!, :recording, key: "", action: "workspaces.download", limit: 1, period: 60
    )
    assert RecordingStudioDownloadable::RateLimiter.send(
      :throttle_bucket!, :recording, key: "   ", action: "workspaces.download", limit: 1, period: 60
    )

    period = 60
    window = Time.now.to_i / period
    refute Rails.cache.exist?("rs_downloadable:rate:workspaces.download:recording::#{window}")
    refute Rails.cache.exist?("rs_downloadable:rate:workspaces.download:recording:   :#{window}")
  end

  test "shared limiter writes the legacy fixed-window cache key shape" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 100, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 5, period: 1.minute }
    }

    action = @recording.downloadable_action
    period = 60
    window = Time.now.to_i / period
    expected = "rs_downloadable:rate:#{action}:recording:#{@recording.id}:#{window}"

    RecordingStudioDownloadable::RateLimiter.throttle!(
      action: action,
      ip: "127.0.0.1",
      actor: @user,
      recording: @recording
    )

    assert Rails.cache.exist?(expected), "expected cache key #{expected}"
  end

  test "cache errors fail open like the prior StandardError rescue" do
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 1, period: 1.minute },
      actor: { limit: 1, period: 1.minute },
      recording: { limit: 1, period: 1.minute }
    }

    boom = Object.new
    def boom.increment(*) = raise(StandardError, "cache down")
    def boom.write(*) = raise(StandardError, "cache down")
    def boom.read(*) = raise(StandardError, "cache down")

    RecordingStudioDownloadable.configuration.cache = boom

    assert RecordingStudioDownloadable::RateLimiter.allowed?(
      action: @recording.downloadable_action,
      ip: "127.0.0.1",
      actor: @user,
      recording: @recording
    )
  end

  test "nil blank and non-positive limits skip throttling like main" do
    action = "workspaces.download"
    [nil, "", "  ", 0, -1, "0"].each do |limit|
      assert RecordingStudioDownloadable::RateLimiter.send(
        :throttle_bucket!, :ip, key: "1.2.3.4", action: action, limit: limit, period: 60
      ), "expected allow for limit=#{limit.inspect}"
    end

    window = Time.now.to_i / 60
    refute Rails.cache.exist?("rs_downloadable:rate:#{action}:ip:1.2.3.4:#{window}")
  end

  test "string period values coerce like main window math and still enforce" do
    action = "workspaces.download"
    memory = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioDownloadable.configuration.cache = memory

    assert RecordingStudioDownloadable::RateLimiter.send(
      :throttle_bucket!, :ip, key: "9.9.9.9", action: action, limit: 1, period: "60"
    )
    error = assert_raises(RecordingStudioDownloadable::RateLimitedError) do
      RecordingStudioDownloadable::RateLimiter.send(
        :throttle_bucket!, :ip, key: "9.9.9.9", action: action, limit: 1, period: "60"
      )
    end
    assert_includes error.message, "Too many download requests"

    window = Time.now.to_i / 60
    assert memory.exist?("rs_downloadable:rate:#{action}:ip:9.9.9.9:#{window}")
  end

  test "config.cache is used as the rate limit store" do
    action = @recording.downloadable_action
    memory = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioDownloadable.configuration.cache = memory
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 100, period: 1.minute },
      actor: { limit: 100, period: 1.minute },
      recording: { limit: 5, period: 1.minute }
    }

    RecordingStudioDownloadable::RateLimiter.throttle!(
      action: action,
      ip: "127.0.0.1",
      actor: @user,
      recording: @recording
    )

    window = Time.now.to_i / 60
    expected = "rs_downloadable:rate:#{action}:recording:#{@recording.id}:#{window}"
    assert memory.exist?(expected), "expected key on config.cache store"
    refute Rails.cache.exist?(expected), "must not write to Rails.cache when config.cache is set"
  end

  test "NullStore short-circuits like main and never rate limits" do
    action = "workspaces.download"
    RecordingStudioDownloadable.configuration.cache = ActiveSupport::Cache::NullStore.new

    5.times do
      assert RecordingStudioDownloadable::RateLimiter.send(
        :throttle_bucket!, :ip, key: "8.8.8.8", action: action, limit: 1, period: 60
      )
    end

    refute RecordingStudioDownloadable::RateLimiter.send(
      :cache_usable?, RecordingStudioDownloadable.configuration.cache_store
    )
  end
end

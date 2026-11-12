# frozen_string_literal: true

require_relative "downloadable_test_helper"

class DownloadableApiActionsTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = User.create!(email: "api-dl-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @viewer = User.create!(email: "api-view-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @stranger = User.create!(email: "api-out-#{SecureRandom.hex(4)}@example.com", password: "Password",
                             password_confirmation: "Password")
    Current.actor = @owner
    @recording = create_workspace_recording
    grant_download_access!(@recording, @owner)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @owner)
    @owner_access = access_for(@recording, @owner)
    @viewer_access = grant_view!(@recording, @viewer)
    @owner_token, = token_for(@owner_access)
    @viewer_token, = token_for(@viewer_access)
  end

  teardown { Current.actor = @previous_actor }

  test "download authorizes then generates for an actor who can use the HTML package" do
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      payload = call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @owner_token)
      assert_response :success, response.body
      assert_equal "pending", payload.fetch("state")
      refute payload.fetch("ready")
      refute payload.key?("download_url")
      refute payload.key?("url")
    end

    perform_enqueued_jobs

    status = call(:get, "/workspaces/#{@recording.id}/actions/downloadable_package_status", @owner_token)
    assert_response :success, response.body
    assert_equal "ready", status.fetch("state")
    assert status.fetch("ready")
    refute status.key?("download_url")
  end

  test "package_status reads downloadable_package without enqueueing" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      payload = call(:get, "/workspaces/#{@recording.id}/actions/downloadable_package_status", @owner_token)
      assert_response :success, response.body
      assert_equal "ready", payload.fetch("state")
      assert_equal @recording.downloadable_package&.failed? || false, payload.fetch("failed")
    end
  end

  test "download and package_status are forbidden without the HTML download role" do
    with_action_audience(:"workspaces.download", download_audience(granted_roles: %i[edit admin])) do
      call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @viewer_token)
      assert_response :forbidden, response.body
      call(:get, "/workspaces/#{@recording.id}/actions/downloadable_package_status", @viewer_token)
      assert_response :forbidden, response.body
    end
    assert_nil @recording.reload.downloadable_package
  end

  test "a viewer with the HTML download role can download and read status" do
    call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @viewer_token)
    assert_response :success, response.body
    payload = call(:get, "/workspaces/#{@recording.id}/actions/downloadable_package_status", @viewer_token)
    assert_response :success, response.body

    assert_equal "pending", payload.fetch("state")
  end

  test "download and package_status cannot see a recording in another workspace" do
    foreign = create_workspace_recording
    RecordingStudioAccessible.bootstrap_owner_access!(recording: foreign, actor: @stranger)

    call(:post, "/workspaces/#{foreign.id}/actions/downloadable_download", @owner_token)
    assert_response :not_found, response.body
    call(:get, "/workspaces/#{foreign.id}/actions/downloadable_package_status", @owner_token)
    assert_response :not_found, response.body
    assert_nil foreign.downloadable_package
  end

  test "a blocking download gate fails closed" do
    gate = Class.new do
      def self.satisfied?(**)
        false
      end
    end

    with_download_gate(@recording.downloadable_action, gate) do
      call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @owner_token)
      assert_response :forbidden, response.body
    end
    assert_nil @recording.reload.downloadable_package
  end

  test "per-type auth_roles override is resolved per recording" do
    with_downloadable_options(Workspace, source: :attachments, format: :zip, auth_roles: { download: :edit }) do
      call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @viewer_token)
      assert_response :forbidden, response.body
      call(:post, "/workspaces/#{@recording.id}/actions/downloadable_download", @owner_token)
      assert_response :success, response.body
    end
  end

  test "scoped downloadable actions are registered on the public API" do
    download = RecordingStudioApi.capability_action(:downloadable_download)
    status = RecordingStudioApi.capability_action(:downloadable_package_status)

    assert download
    assert_equal :downloadable, download.capability
    assert_equal :post, download.http_verb
    assert_equal RecordingStudioDownloadable::Api.download_role, download.required_role
    assert_equal RecordingStudioDownloadable::Api::DownloadRecording, download.handler

    assert status
    assert_equal :downloadable, status.capability
    assert_equal :get, status.http_verb
    assert_equal RecordingStudioDownloadable::Api.download_role, status.required_role
    assert_equal RecordingStudioDownloadable::Api::PackageStatus, status.handler
  end

  test "re-registering this gem's actions does not raise" do
    assert_nil RecordingStudioDownloadable::Api.register_capability_action!
  end

  test "a colliding capability action raises" do
    foreign = Struct.new(:capability, :handler).new(:movable, Object.new)

    RecordingStudioApi.stub(:capability_action, foreign) do
      error = assert_raises(RecordingStudioApi::ConfigurationError) do
        RecordingStudioDownloadable::Api.register_capability_action!
      end
      assert_match(/already registered/, error.message)
    end
  end

  test "metrics api_authorize matches admin download history access" do
    assert defined?(RecordingStudioMetrics)

    hook = RecordingStudioMetrics.registry.api_authorize_for(:download_logs)
    assert hook

    assert hook.call(metrics_context(actor: @owner, recording: @recording))
    refute hook.call(metrics_context(actor: @viewer, recording: @recording))
    refute hook.call(metrics_context(actor: @stranger, recording: @recording))

    foreign = create_workspace_recording
    refute hook.call(metrics_context(actor: @owner, recording: foreign))
  end

  private

  def download_audience(granted_roles:)
    {
      allowed: %i[granted],
      default: :granted,
      granted_roles: granted_roles,
      granted_override: true,
      manage_role: :admin
    }
  end

  def access_for(recording, actor)
    RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Access").find do |access_recording|
      access = access_recording.recordable
      access.respond_to?(:actor) && access.actor == actor &&
        (access_recording.parent_recording_id == recording.id || access_recording.root_recording_id == recording.id)
    end
  end

  def grant_view!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def call(method, path, token, params = {})
    send(
      method,
      "#{BASE}#{path}",
      params: params,
      headers: { "Authorization" => "Bearer #{token}", "Accept" => "application/json" },
      as: :json
    )
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def metrics_context(actor:, recording:)
    grant = Struct.new(:actor, :access_recording).new(actor, recording)
    Struct.new(:access_grant).new(grant)
  end
end

# frozen_string_literal: true

require "test_helper"
require_relative "../../support/attachable_direct_upload"

class DownloadableNamedMcpToolsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "mcp-dl-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @owner
    @recording = workspace_recording
    grant_studio_download_access!(@recording, @owner)
    AttachableDirectUpload.upload!(
      recording: @recording,
      actor: @owner,
      filename: "pack.txt",
      content: "packed"
    )
    @token = issue_token
  end

  teardown { Current.actor = @previous_actor }

  test "named tools are listed and the generic capability action is rejected" do
    listed = rpc("tools/list")
    tools = listed.dig("result", "tools")
    flunk listed.to_json if tools.nil?

    names = tools.map { |tool| tool.fetch("name") }
    assert_includes names, "download_workspace"
    assert_includes names, "download_page"
    assert_includes names, "download_press_kit"
    refute_includes names, "download_folder"
    refute_includes names, "download"
    refute_includes names, "capability_action"
    refute_includes names, "downloadable_download"
    refute_includes names, "downloadable_package_status"
    refute_includes names, "download_recording"
    refute_includes names, "read_package_status"

    download = tools.find { |tool| tool.fetch("name") == "download_press_kit" }
    assert_includes download.fetch("description"), "press kit"
    assert_includes download.fetch("description"), "background"
    assert_includes download.fetch("description"), "state, ready, stale"
    refute_match(/\b(Access|role|View|Edit|Admin)\b/, download.fetch("description"))

    rejected = rpc(
      "tools/call",
      name: "capability_action",
      arguments: { type: "Workspace", id: @recording.id.to_s, action: "downloadable_download" }
    )
    assert rejected.dig("result", "isError") || rejected["error"], rejected.to_json
  end

  test "download_workspace returns package status and not a url" do
    called = rpc(
      "tools/call",
      name: "download_workspace",
      arguments: { id: @recording.id.to_s }
    )
    refute called.dig("result", "isError"), called.to_json
    payload = tool_payload(called)

    assert_includes %w[pending ready], payload.fetch("state")
    assert_includes [true, false], payload.fetch("ready")
    assert_includes [true, false], payload.fetch("stale")
    assert_includes [true, false], payload.fetch("failed")
    refute payload.key?("url")
    refute payload.key?("download_url")
  end

  private

  def workspace_recording
    workspace = Workspace.create!(name: "MCP download #{SecureRandom.hex(4)}")
    RecordingStudio.create_root_recording!(workspace, actor: @owner)
  end

  def issue_token
    access = RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Access").find do |access_recording|
      access_recording.recordable.respond_to?(:actor) && access_recording.recordable.actor == @owner &&
        access_recording.root_recording_id == @recording.id
    end
    raise "missing access recording" if access.nil?

    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access.parent_recording || access.root_recording,
      manager_actor: @owner,
      role: access.recordable.role,
      name: "MCP #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    issued.value.fetch(:access_token)
  end

  def rpc(method, **params)
    post "/recording_studio_mcp",
         params: { jsonrpc: "2.0", id: SecureRandom.random_number(1_000), method: method, params: params }.to_json,
         headers: {
           "Content-Type" => "application/json",
           "Accept" => "application/json",
           "Authorization" => "Bearer #{@token}"
         }
    assert_response :success, response.body
    JSON.parse(response.body)
  end

  def tool_payload(body)
    structured = body.dig("result", "structuredContent")
    return structured if structured.is_a?(Hash) && structured.key?("state")

    JSON.parse(body.dig("result", "content", 0, "text").to_s)
  end
end

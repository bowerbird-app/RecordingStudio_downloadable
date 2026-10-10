# frozen_string_literal: true

require_relative "downloadable_test_helper"

class DomainHookTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "hook-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user
  end

  teardown do
    Workspace.remove_method(:downloadable_available_for?) if Workspace.method_defined?(:downloadable_available_for?)
  end

  test "domain hook runs after the audience check and can deny a granted actor" do
    Workspace.define_method(:downloadable_available_for?) do |actor:, action:|
      _actor = actor
      _action = action
      false
    end

    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
    assert_nil response.redirect_url
  end

  test "domain hook exception fails closed" do
    Workspace.define_method(:downloadable_available_for?) do |**|
      raise "boom"
    end

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
  end

  test "granted_override still requires the domain hook" do
    Workspace.define_method(:downloadable_available_for?) do |**|
      false
    end

    audience = RecordingStudioAccessible.configuration.action_audiences[:"workspaces.download"]
    assert_equal true, audience[:granted_override]
    refute RecordingStudioDownloadable::Authorization.allowed?(
      action: @recording.downloadable_action,
      actor: @user,
      recording: @recording
    )
  end
end

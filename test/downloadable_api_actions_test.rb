# frozen_string_literal: true

require_relative "downloadable_test_helper"

class DownloadableApiActionsTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  HandlerContext = Struct.new(:recording, :access_grant, keyword_init: true)

  class TestAccessGrant
    class Denied < StandardError; end

    def initialize(actor:, root:)
      @actor = actor
      @root = root
    end

    attr_reader :actor, :root

    def accessible_recordings
      RecordingStudio::Recording.unscoped.where(root_recording_id: @root.id)
                                .or(RecordingStudio::Recording.unscoped.where(id: @root.id))
    end

    def authorize!(recording:, role:)
      unless accessible_recordings.exists?(id: recording.id)
        raise Denied, "API access grant is not authorized for this capability"
      end
      return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

      raise Denied, "API access grant is not authorized for this capability"
    end
  end

  setup do
    @owner = User.create!(email: "api-dl-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @viewer = User.create!(email: "api-view-#{SecureRandom.hex(4)}@example.com", password: "Password",
                           password_confirmation: "Password")
    @stranger = User.create!(email: "api-out-#{SecureRandom.hex(4)}@example.com", password: "Password",
                             password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @owner)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @owner)
    @grant = TestAccessGrant.new(actor: @owner, root: @recording)
  end

  test "download authorizes then generates for an actor who can use the HTML package" do
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      payload = RecordingStudioDownloadable::Api::DownloadRecording.call(context_for(@recording, @grant))
      assert_equal "pending", payload.fetch(:state)
      refute payload.fetch(:ready)
    end

    perform_enqueued_jobs

    status = RecordingStudioDownloadable::Api::PackageStatus.call(context_for(@recording, @grant))
    assert_equal "ready", status.fetch(:state)
    assert status.fetch(:ready)
  end

  test "package_status reads downloadable_package without enqueueing" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      payload = RecordingStudioDownloadable::Api::PackageStatus.call(context_for(@recording, @grant))
      assert_equal "ready", payload.fetch(:state)
      assert_equal @recording.downloadable_package&.failed? || false, payload.fetch(:failed)
    end
  end

  test "download and package_status are forbidden without the HTML download role" do
    denied = TestAccessGrant.new(actor: @stranger, root: @recording)

    assert_raises(TestAccessGrant::Denied) do
      RecordingStudioDownloadable::Api::DownloadRecording.call(context_for(@recording, denied))
    end
    assert_raises(TestAccessGrant::Denied) do
      RecordingStudioDownloadable::Api::PackageStatus.call(context_for(@recording, denied))
    end
    assert_nil @recording.downloadable_package
  end

  test "a viewer with the HTML download role can download and read status" do
    grant_view!(@recording, @viewer)
    view_grant = TestAccessGrant.new(actor: @viewer, root: @recording)

    RecordingStudioDownloadable::Api::DownloadRecording.call(context_for(@recording, view_grant))
    payload = RecordingStudioDownloadable::Api::PackageStatus.call(context_for(@recording, view_grant))

    assert_equal "pending", payload.fetch(:state)
  end

  test "download and package_status cannot see a recording in another workspace" do
    foreign = create_workspace_recording
    RecordingStudioAccessible.bootstrap_owner_access!(recording: foreign, actor: @owner)

    error = assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioDownloadable::Api::DownloadRecording.call(context_for(foreign, @grant))
    end
    assert_includes error.message, "this API scope"

    error = assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioDownloadable::Api::PackageStatus.call(context_for(foreign, @grant))
    end
    assert_includes error.message, "this API scope"
    assert_nil foreign.downloadable_package
  end

  test "metrics api_authorize matches admin download history access" do
    skip "RecordingStudio_metrics is not loaded" unless defined?(RecordingStudioMetrics)

    hook = RecordingStudioMetrics.registry.api_authorize_for(:download_logs)
    assert hook

    assert hook.call(metrics_context(actor: @owner, recording: @recording))

    grant_view!(@recording, @viewer)
    refute hook.call(metrics_context(actor: @viewer, recording: @recording))
    refute hook.call(metrics_context(actor: @stranger, recording: @recording))

    foreign = create_workspace_recording
    refute hook.call(metrics_context(actor: @owner, recording: foreign))
  end

  private

  def context_for(recording, grant)
    HandlerContext.new(recording: recording, access_grant: grant)
  end

  def metrics_context(actor:, recording:)
    grant = Struct.new(:actor, :root_recording).new(actor, recording)
    Struct.new(:access_grant, :access_recording, :root_recording).new(grant, recording, recording)
  end

  def grant_view!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end
end

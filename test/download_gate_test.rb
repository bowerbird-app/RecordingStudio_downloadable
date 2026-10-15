# frozen_string_literal: true

require_relative "downloadable_test_helper"

class ExampleDownloadGate
  class << self
    attr_accessor :open, :meta, :url, :explode, :continuation_explodes

    def satisfied?(**)
      raise "gate down" if explode

      !!open
    end

    def continuation_url(**)
      raise "no url" if continuation_explodes

      url
    end

    def metadata_for(**)
      raise "meta down" if meta == :raise

      meta
    end
  end
end

class DownloadGateTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "gate-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @other = User.create!(email: "gate-other-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user

    @config = RecordingStudioDownloadable.configuration
    @previous_gates = @config.download_gates.dup
    @previous_cache = @config.cache
    @previous_limits = @config.rate_limits.deep_dup
    @config.download_gates.clear
    @config.register_download_gate(:"workspaces.download", ExampleDownloadGate)
    ExampleDownloadGate.open = false
    ExampleDownloadGate.meta = { "purpose" => "launch" }
    ExampleDownloadGate.url = "/continue-download"
    ExampleDownloadGate.explode = false
    ExampleDownloadGate.continuation_explodes = false
    perform_enqueued_jobs { @recording.downloadable_generate! }
  end

  teardown do
    @config.download_gates.replace(@previous_gates)
    @config.cache = @previous_cache
    @config.rate_limits = @previous_limits
  end

  test "an unsatisfied gate redirects html and does not log, enqueue, or burn the rate limit" do
    @config.cache = ActiveSupport::Cache::MemoryStore.new
    @config.rate_limits = {
      ip: { limit: 1, period: 1.minute },
      actor: { limit: 1, period: 1.minute },
      recording: { limit: 1, period: 1.minute }
    }

    assert_no_difference -> { logs_for(@recording).count } do
      assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
        get recording_studio_downloadable.recording_package_path(@recording)
      end
    end

    assert_redirected_to "/continue-download"

    ExampleDownloadGate.open = true
    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    refute_includes response.redirect_url, "continue-download"
    assert_equal({ "purpose" => "launch" }, logs_for(@recording).sole.metadata)
  end

  test "iframe xhr and json package gets return 409 and do not log" do
    assert_no_difference -> { logs_for(@recording).count } do
      get recording_studio_downloadable.recording_package_path(@recording), as: :json
      assert_conflict_url "/continue-download"

      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "Sec-Fetch-Dest" => "iframe" }
      assert_conflict_url "/continue-download"

      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "X-Requested-With" => "XMLHttpRequest" }
      assert_conflict_url "/continue-download"
    end
  end

  test "a missing continuation url conflicts without logging" do
    ExampleDownloadGate.continuation_explodes = true

    assert_no_difference -> { logs_for(@recording).count } do
      get recording_studio_downloadable.recording_package_path(@recording)
      assert_response :conflict

      get recording_studio_downloadable.recording_package_path(@recording), as: :json
      assert_response :conflict
      assert_nil JSON.parse(response.body)["continuation_url"]
    end
  end

  test "a broken satisfied check blocks the download" do
    ExampleDownloadGate.explode = true

    assert_no_difference -> { logs_for(@recording).count } do
      get recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_redirected_to "/continue-download"
  end

  test "create and status stay gate-free and do not log" do
    ExampleDownloadGate.explode = true

    assert_no_difference -> { logs_for(@recording).count } do
      post recording_studio_downloadable.recording_package_path(@recording)
      assert_response :redirect
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      assert_response :success
    end
  end

  test "an unsatisfied show clears the autostart flag" do
    post recording_studio_downloadable.recording_package_path(@recording)

    assert_equal @recording.id, session[:recording_studio_downloadable_autostart]

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_nil session[:recording_studio_downloadable_autostart]
    assert_equal 0, logs_for(@recording).count
  end

  test "an empty package still stops at the gate" do
    empty = create_workspace_recording
    grant_download_access!(empty, @user)

    get recording_studio_downloadable.recording_package_path(empty)

    assert_redirected_to "/continue-download"
    assert_equal 0, logs_for(empty).count
  end

  test "a denied request never reaches the gate" do
    sign_in @other
    ExampleDownloadGate.explode = true

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :forbidden
    assert_equal 0, logs_for(@recording).count
  end

  test "a satisfied download logs sanitized metadata and a second download logs again" do
    ExampleDownloadGate.open = true
    ExampleDownloadGate.meta = {
      "purpose" => "launch",
      "Bad-Key" => { "nope" => true },
      "note" => "n" * 201
    }

    2.times { get recording_studio_downloadable.recording_package_path(@recording) }

    logs = logs_for(@recording).order(:created_at)
    assert_equal 2, logs.count
    assert_equal [{ "purpose" => "launch" }, { "purpose" => "launch" }], logs.map(&:metadata)
  end

  test "a metadata exception still logs the download" do
    ExampleDownloadGate.open = true
    ExampleDownloadGate.meta = :raise

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    refute_includes response.redirect_url, "continue-download"
    assert_equal({}, logs_for(@recording).sole.metadata)
  end

  private

  def logs_for(recording)
    RecordingStudioDownloadable::DownloadLog.where(recording_id: recording.id)
  end

  def assert_conflict_url(url)
    assert_response :conflict
    assert_equal url, JSON.parse(response.body)["continuation_url"]
  end
end

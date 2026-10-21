# frozen_string_literal: true

require_relative "downloadable_test_helper"

module DownloadLogTestHooks
  def show
    Current.impersonator = Thread.current[:download_log_impersonator] if Thread.current.key?(:download_log_impersonator)
    super
  end
end

module DownloadLogInsertFailure
  def record!(**kwargs)
    raise ActiveRecord::ActiveRecordError, "forced insert failure" if Thread.current[:force_download_log_failure]

    super
  end
end

RecordingStudioDownloadable::PackagesController.prepend(DownloadLogTestHooks)
RecordingStudioDownloadable::DownloadLog.singleton_class.prepend(DownloadLogInsertFailure)

class DownloadLogsTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "log-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @other = User.create!(email: "log-other-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user
  end

  teardown do
    Thread.current[:download_log_impersonator] = nil
    Thread.current[:force_download_log_failure] = nil
  end

  test "a ready download writes one log and leaves the event stream alone" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    events_before = RecordingStudio::Event.count

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    assert_equal 1, logs_for(@recording).count
    log = logs_for(@recording).first
    assert_equal @recording.downloadable_action.to_s, log.action
    assert_equal "public", log.export_scope
    assert_equal({}, log.metadata)
    assert_equal @user, log.actor
    assert_nil log.impersonator
    assert_predicate log.ip_address, :present?
    assert_predicate log.occurred_at, :present?
    refute_includes log.attributes.values.map(&:to_s), response.redirect_url.to_s
    assert_equal events_before, RecordingStudio::Event.count
    assert_equal "recording_studio_downloadable_download_logs", RecordingStudioDownloadable::DownloadLog.table_name
  end

  test "a second ready download appends another log" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    2.times { get recording_studio_downloadable.recording_package_path(@recording) }

    assert_equal 2, logs_for(@recording).count
  end

  test "anonymous downloads log a null actor" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    sign_out @user
    with_action_audience(:"workspaces.download", public_audience) do
      get recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_response :redirect
    log = logs_for(@recording).sole
    assert_nil log.actor_type
    assert_nil log.actor_id
  end

  test "impersonator is stored from Current" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    Thread.current[:download_log_impersonator] = @other

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_equal @other, logs_for(@recording).sole.impersonator
  end

  test "metadata keeps scalars and drops the rest" do
    log = nil
    warnings = capture_metadata_warnings do
      log = RecordingStudioDownloadable::DownloadLog.record!(
        recording: @recording, action: "workspaces.download", export_scope: "public",
        actor: @user, metadata: mixed_metadata
      )
    end

    assert_equal(
      { "purpose" => "launch", "confirmed" => false, "count" => 2, "ratio" => 1.5, "note" => nil },
      log.reload.metadata
    )
    assert_includes warnings, "download log metadata dropped"
  end

  test "metadata keeps at most 32 keys and 2KB" do
    wide = 40.times.to_h { |index| [format("key_%02d", index), index] }
    long = 16.times.to_h { |index| [format("blob_%02d", index), "b" * 200] }

    warnings = capture_metadata_warnings do
      wide_log = RecordingStudioDownloadable::DownloadLog.record!(
        recording: @recording, action: "workspaces.download", export_scope: "public", metadata: wide
      )
      long_log = RecordingStudioDownloadable::DownloadLog.record!(
        recording: @recording, action: "workspaces.download", export_scope: "public", metadata: long
      )

      assert_equal 32, wide_log.reload.metadata.size
      assert_equal 0, wide_log.metadata["key_00"]
      refute wide_log.metadata.key?("key_32")
      assert_operator long_log.reload.metadata.size, :<, 16
      assert_operator ActiveSupport::JSON.encode(long_log.metadata).bytesize, :<=, 2_048
    end

    assert_includes warnings, "download log metadata dropped"
  end

  test "metadata has no index" do
    indexes = RecordingStudioDownloadable::DownloadLog.connection.indexes(
      RecordingStudioDownloadable::DownloadLog.table_name
    )

    refute(indexes.any? { |index| Array(index.columns).include?("metadata") })
  end

  test "a non-hash metadata value is dropped and the row is still written" do
    warnings = capture_metadata_warnings do
      log = RecordingStudioDownloadable::DownloadLog.record!(
        recording: @recording,
        action: "workspaces.download",
        export_scope: "public",
        metadata: "nope"
      )

      assert_equal({}, log.reload.metadata)
    end

    assert_includes warnings, "expected a hash"
  end

  test "user agents are truncated before save" do
    agent = "x" * (RecordingStudioDownloadable::DownloadLog::USER_AGENT_LIMIT + 40)
    log = RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording,
      action: "workspaces.download",
      export_scope: "public",
      actor: @user,
      user_agent: agent
    )

    assert_equal RecordingStudioDownloadable::DownloadLog::USER_AGENT_LIMIT, log.user_agent.length
  end

  test "record! stamps the recording root" do
    log = RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording,
      action: "workspaces.download",
      export_scope: "public",
      actor: @user
    )

    assert_equal @recording.id, log.root_recording_id
    assert_equal @recording.id, @recording.root_recording_id
  end

  test "rows are append-only" do
    log = RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording,
      action: "workspaces.download",
      export_scope: "public",
      actor: @user
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) { log.update!(metadata: { "purpose" => "nope" }) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.update!(action: "nope") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.delete }
    assert RecordingStudioDownloadable::DownloadLog.exists?(log.id)
  end

  test "trash keeps logs and destroying the recording deletes them" do
    bare = create_workspace_recording
    log = RecordingStudioDownloadable::DownloadLog.record!(
      recording: bare,
      action: "workspaces.download",
      export_scope: "public",
      actor: @user
    )
    bare.update!(trashed_at: Time.current)

    assert RecordingStudioDownloadable::DownloadLog.exists?(log.id)

    bare.destroy!

    refute RecordingStudioDownloadable::DownloadLog.exists?(log.id)
  end

  test "create status and generation do not log" do
    assert_no_difference -> { logs_for(@recording).count } do
      post recording_studio_downloadable.recording_package_path(@recording)
      perform_enqueued_jobs
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
    end
  end

  test "denied requests do not log" do
    sign_in @other

    assert_no_difference -> { RecordingStudioDownloadable::DownloadLog.count } do
      get recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_response :forbidden
  end

  test "stale packages do not log" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    attach_file!(@recording, filename: "extra.txt", contents: "more", actor: @user)

    assert_no_difference -> { logs_for(@recording).count } do
      get recording_studio_downloadable.recording_package_path(@recording),
          headers: { "HTTP_REFERER" => "http://www.example.com/pages" }
    end

    assert_redirected_to "http://www.example.com/pages"
  end

  test "empty and failed packages do not log" do
    empty = create_workspace_recording
    grant_download_access!(empty, @user)
    assert_no_difference -> { logs_for(empty).count } do
      get recording_studio_downloadable.recording_package_path(empty)
    end
    assert_response :not_found

    failed = create_workspace_recording
    grant_download_access!(failed, @user)
    attach_file!(failed, filename: "pack.txt", contents: "packed", actor: @user)
    RecordingStudioDownloadable::Package.create!(
      recording: failed,
      format: "zip",
      action: failed.downloadable_action.to_s,
      export_scope: "public",
      state: "failed",
      failure_message: "nope"
    )
    assert_no_difference -> { logs_for(failed).count } do
      get recording_studio_downloadable.recording_package_path(failed)
    end
  end

  test "a rate limited download does not log" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    previous_cache = RecordingStudioDownloadable.configuration.cache
    previous_limits = RecordingStudioDownloadable.configuration.rate_limits.deep_dup
    RecordingStudioDownloadable.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioDownloadable.configuration.rate_limits = {
      ip: { limit: 1, period: 1.minute },
      actor: { limit: 60, period: 1.minute },
      recording: { limit: 60, period: 1.minute }
    }

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_equal 1, logs_for(@recording).count

    get recording_studio_downloadable.recording_package_path(@recording)
    assert_response :too_many_requests
    assert_equal 1, logs_for(@recording).count
  ensure
    RecordingStudioDownloadable.configuration.cache = previous_cache
    RecordingStudioDownloadable.configuration.rate_limits = previous_limits
  end

  test "an insert failure still redirects to the archive" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    Thread.current[:force_download_log_failure] = true

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    assert_predicate response.redirect_url, :present?
    assert_equal 0, logs_for(@recording).count
  end

  test "metrics execute against the recording relation when metrics is loaded" do
    skip "RecordingStudio_metrics is not loaded" unless defined?(RecordingStudioMetrics)

    other = create_workspace_recording
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: @recording, action: "workspaces.download", export_scope: "public", actor: @user
    )
    RecordingStudioDownloadable::DownloadLog.record!(
      recording: other, action: "workspaces.download", export_scope: "public", actor: @user
    )

    context = RecordingStudioDownloadable::MetricsRegistration.context_for(recording: @recording, actor: @user)
    assert_includes context.authorized_relation.to_sql, @recording.id
    refute_includes context.authorized_relation.to_sql, other.id

    total = RecordingStudioMetrics.execute(
      RecordingStudioDownloadable::MetricsRegistration::TOTAL_METRIC,
      context: context,
      cache: false
    )
    assert_equal 1, total.value

    series = RecordingStudioMetrics.execute(
      RecordingStudioDownloadable::MetricsRegistration::TIMESERIES_METRIC,
      context: context,
      interval: :day,
      start_at: 2.days.ago,
      end_at: Time.current
    )
    assert_predicate series.data, :present?
  end

  private

  def mixed_metadata
    {
      purpose: "launch",
      "confirmed" => false,
      "count" => 2,
      "ratio" => 1.5,
      "note" => nil,
      "Bad-Key" => "nope",
      "nested" => { "a" => 1 },
      "list" => [1],
      "essay" => "e" * 201,
      "infinite" => Float::INFINITY,
      12 => "nope"
    }
  end

  def capture_metadata_warnings
    previous = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def logs_for(recording)
    RecordingStudioDownloadable::DownloadLog.where(recording_id: recording.id)
  end

  def public_audience
    {
      allowed: %i[public granted],
      default: :public,
      granted_roles: %i[view edit admin],
      granted_override: true,
      manage_role: :admin
    }
  end
end

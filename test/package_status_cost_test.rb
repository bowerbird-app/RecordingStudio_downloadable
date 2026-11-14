# frozen_string_literal: true

require_relative "downloadable_test_helper"

class PackageStatusCostTest < ActionDispatch::IntegrationTest
  include DownloadableTestHelper
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "cost-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    sign_in @user
  end

  teardown do
    remove_workspace_status_hooks!
  end

  test "status with a cache key does not build the manifest" do
    install_status_hooks!(key: "one", empty: false)
    perform_enqueued_jobs { @recording.downloadable_generate! }
    assert @recording.reload.downloadable_ready?

    counter = nil
    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      counter = count_file_collects do
        get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      end
    end

    assert_equal 0, counter[:calls]
    assert_response :success
    assert_equal true, response.parsed_body["ready"]
    assert_equal false, response.parsed_body["stale"]
  end

  test "show of a ready package trusts the cache key and does not build the manifest" do
    install_status_hooks!(key: "one", empty: false)
    perform_enqueued_jobs { @recording.downloadable_generate! }

    counter = count_file_collects do
      get recording_studio_downloadable.recording_package_path(@recording)
    end

    assert_equal 0, counter[:calls]
    assert_response :redirect
    assert_match(%r{active_storage|X-Amz-Signature|rails/active_storage}i, response.redirect_url.to_s)
  end

  test "a changed cache key is stale and status enqueues without building the manifest" do
    install_status_hooks!(key: "one", empty: false)
    perform_enqueued_jobs { @recording.downloadable_generate! }
    Workspace.instance_variable_set(:@downloadable_status_cache_key, "two")

    assert @recording.reload.downloadable_stale?
    refute @recording.downloadable_ready?

    counter = nil
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      counter = count_file_collects do
        get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      end
    end

    assert_equal 0, counter[:calls]
    assert_equal false, response.parsed_body["ready"]
    assert_nil response.parsed_body["download_url"]
    assert_includes %w[pending processing], @recording.reload.downloadable_package.state
  end

  test "the build leaves the package unready when the cache key changes mid-zip" do
    package, seen = build_while_cache_key_changes
    assert_unready_after_key_change(package, seen)
  end

  test "a stable cache key is what the package stores" do
    install_status_hooks!(key: "stable", empty: false)
    perform_enqueued_jobs { @recording.downloadable_generate! }

    package = @recording.reload.downloadable_package
    assert package.ready?
    assert_equal @recording.downloadable_cache_key, package.source_fingerprint
    refute_equal @recording.downloadable_source_fingerprint, package.source_fingerprint

    counter = count_file_collects do
      RecordingStudioDownloadable::Services::GeneratePackage.call(package: package)
    end
    assert_equal 0, counter[:calls]
    assert package.reload.ready?
  end

  test "without the hook the stored key is still the file fingerprint" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    package = @recording.reload.downloadable_package
    assert_equal @recording.downloadable_source_fingerprint, package.source_fingerprint
    assert_equal @recording.downloadable_cache_key, package.source_fingerprint
  end

  test "without the hook one status request collects files once" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    counter = count_file_collects do
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
    end

    assert_equal 1, counter[:calls]
    assert_equal true, response.parsed_body["ready"]
  end

  test "ready stale and ready again share one file collect inside a request" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    @recording.reload

    inside = count_file_collects do
      RecordingStudioDownloadable::RequestMemo.with_request_memo do
        @recording.downloadable_ready?
        @recording.downloadable_stale?
        @recording.downloadable_ready?
      end
    end
    assert_equal 1, inside[:calls]

    outside = count_file_collects do
      @recording.downloadable_ready?
      @recording.downloadable_stale?
      @recording.downloadable_ready?
    end
    assert_equal 3, outside[:calls]
  end

  test "an empty hook skips the manifest on show" do
    install_status_hooks!(key: "one", empty: true)

    counter = nil
    assert_no_enqueued_jobs only: RecordingStudioDownloadable::GeneratePackageJob do
      counter = count_file_collects do
        get recording_studio_downloadable.recording_package_path(@recording)
      end
    end

    assert_equal 0, counter[:calls]
    assert_response :not_found
  end

  test "cache key is scoped by action and export scope" do
    install_status_hooks!(key: "same", empty: false)

    public_key = @recording.downloadable_cache_key(export_scope: :public)
    draft_key = @recording.downloadable_cache_key(export_scope: :draft)
    other_action = @recording.downloadable_cache_key(action: :"kits.download")

    refute_equal public_key, draft_key
    refute_equal public_key, other_action
  end

  private

  def build_while_cache_key_changes
    seen = []
    install_status_hooks!(key: "ignored", empty: false)
    Workspace.define_method(:downloadable_cache_key) do |action:, export_scope:|
      seen << "#{action}:#{export_scope}:#{seen.size}"
      seen.last
    end
    package = RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      action: @recording.downloadable_action.to_s,
      export_scope: "public",
      format: "zip",
      state: "pending",
      source_fingerprint: "old"
    )
    assert_enqueued_jobs 1, only: RecordingStudioDownloadable::GeneratePackageJob do
      result = RecordingStudioDownloadable::Services::GeneratePackage.call(package: package)
      assert result.success?
    end
    [package.reload, seen]
  end

  def assert_unready_after_key_change(package, seen)
    refute package.ready?
    assert_equal "pending", package.state
    refute package.archive.attached?
    assert_operator seen.size, :>=, 2
    refute_equal seen[0], seen[1]
    built = scoped_key(seen[0])
    changed = scoped_key(seen[1])
    assert_equal built, package.source_fingerprint
    refute_equal changed, package.source_fingerprint
  end

  def scoped_key(raw)
    RecordingStudioDownloadable::Fingerprint.host_cache_key(
      raw,
      action: @recording.downloadable_action,
      export_scope: "public"
    )
  end

  def install_status_hooks!(key:, empty:)
    Workspace.instance_variable_set(:@downloadable_status_cache_key, key)
    Workspace.instance_variable_set(:@downloadable_status_empty, empty)
    return if Workspace.method_defined?(:downloadable_cache_key)

    Workspace.define_method(:downloadable_cache_key) do |action:, export_scope:|
      "#{action}:#{export_scope}:#{self.class.instance_variable_get(:@downloadable_status_cache_key)}"
    end
    Workspace.define_method(:downloadable_empty?) do
      self.class.instance_variable_get(:@downloadable_status_empty)
    end
  end

  def remove_workspace_status_hooks!
    Workspace.remove_method(:downloadable_cache_key) if Workspace.method_defined?(:downloadable_cache_key)
    Workspace.remove_method(:downloadable_empty?) if Workspace.method_defined?(:downloadable_empty?)
  end

  def count_file_collects
    counter = { calls: 0 }
    singleton = RecordingStudioDownloadable::Services::CollectFiles.singleton_class
    singleton.alias_method(:call_without_status_count, :call)
    singleton.define_method(:call) do |*args, **kwargs, &block|
      counter[:calls] += 1
      call_without_status_count(*args, **kwargs, &block)
    end
    yield
    counter
  ensure
    singleton.remove_method(:call) if singleton.method_defined?(:call) &&
                                      singleton.instance_method(:call).owner == singleton
    singleton.remove_method(:call_without_status_count) if singleton.method_defined?(:call_without_status_count)
  end
end

class PackageStatusOverlapTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  setup do
    @user = User.create!(email: "overlap-#{SecureRandom.hex(4)}@example.com", password: "Password",
                         password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @user)
    attach_file!(@recording, filename: "pack.txt", contents: "packed", actor: @user)
    install_status_hooks!
  end

  teardown do
    remove_workspace_status_hooks!
    cleanup_overlap_rows!
  end

  test "overlapping polls of a stale package enqueue one build" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    Workspace.instance_variable_set(:@downloadable_status_cache_key, "two")
    clear_enqueued_jobs
    assert @recording.reload.downloadable_stale?

    overlap_generate!(@recording.id) do |recording|
      raise "expected a stale package before either poll enqueues" unless recording.downloadable_stale?
    end

    assert_equal 1, RecordingStudioDownloadable::Package.where(recording_id: @recording.id).count
    assert_includes %w[pending processing], @recording.reload.downloadable_package.state
  end

  test "overlapping polls of a missing package enqueue one build" do
    overlap_generate!(@recording.id) do |recording|
      raise "package already exists" if recording.downloadable_package.present?
    end

    assert_equal 1, RecordingStudioDownloadable::Package.where(recording_id: @recording.id).count
  end

  private

  def overlap_generate!(recording_id, &)
    errors = Queue.new
    entered = Queue.new
    release = Queue.new
    threads = start_overlap_threads(recording_id, entered, release, errors, &)
    2.times { entered.pop }
    before = enqueued_jobs.size
    2.times { release << true }
    threads.each(&:join)
    flunk(errors.pop.full_message) until errors.empty?
    jobs = enqueued_jobs.count { |job| job[:job] == RecordingStudioDownloadable::GeneratePackageJob }
    assert_equal before + 1, jobs
  end

  def start_overlap_threads(recording_id, entered, release, errors, &check)
    Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          recording = RecordingStudio::Recording.find(recording_id)
          check.call(recording)
          entered << true
          release.pop
          recording.downloadable_generate!(force: true)
        end
      rescue StandardError => e
        entered << false
        errors << e
      end
    end
  end

  def install_status_hooks!
    Workspace.instance_variable_set(:@downloadable_status_cache_key, "one")
    return if Workspace.method_defined?(:downloadable_cache_key)

    Workspace.define_method(:downloadable_cache_key) do |action:, export_scope:|
      "#{action}:#{export_scope}:#{self.class.instance_variable_get(:@downloadable_status_cache_key)}"
    end
    Workspace.define_method(:downloadable_empty?) { false }
  end

  def remove_workspace_status_hooks!
    Workspace.remove_method(:downloadable_cache_key) if Workspace.method_defined?(:downloadable_cache_key)
    Workspace.remove_method(:downloadable_empty?) if Workspace.method_defined?(:downloadable_empty?)
  end

  # These tests commit. A leftover pending package counts toward the build cap.
  # Recordings stay; destroying a recordable snapshot is not allowed.
  def cleanup_overlap_rows!
    return if @recording.nil?

    RecordingStudioDownloadable::Package.where(recording_id: @recording.id).delete_all
  end
end

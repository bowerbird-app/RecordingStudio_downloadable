# frozen_string_literal: true

require_relative "downloadable_test_helper"

class PackageIdentityTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  setup do
    @actor = User.create!(email: "id-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
    attach_file!(@recording, filename: "a.txt", contents: "aaa", actor: @actor)
  end

  test "packages are unique per recording action export_scope and format" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    default_package = @recording.downloadable_package

    assert_equal "workspaces.download", default_package.action
    assert_equal "public", default_package.export_scope

    other = RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      action: "account.private_data_export",
      export_scope: "public",
      format: "zip",
      state: "ready",
      source_fingerprint: "other"
    )
    draft = RecordingStudioDownloadable::Package.create!(
      recording: @recording,
      action: "workspaces.download",
      export_scope: "draft",
      format: "zip",
      state: "ready",
      source_fingerprint: "draft"
    )

    assert_equal default_package.id, @recording.downloadable_package.id
    assert_not_equal other.id, @recording.downloadable_package.id
    assert_not_equal draft.id, @recording.downloadable_package.id
    assert_equal other.id, @recording.downloadable_package(action: :"account.private_data_export").id
    assert_equal draft.id, @recording.downloadable_package(export_scope: :draft).id
  end

  test "fingerprint for one action is never current for another" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    package = @recording.downloadable_package

    kit_fingerprint = @recording.downloadable_source_fingerprint(action: :"presskits.kit_download")
    refute_equal package.source_fingerprint, kit_fingerprint
    refute @recording.downloadable_current_fingerprint_matches?(
      package,
      action: :"presskits.kit_download"
    )
    assert @recording.downloadable_current_fingerprint_matches?(package)
  end

  test "existing packages backfill to the derived action and public scope" do
    migration = File.read(
      RecordingStudioDownloadable::Engine.root.join(
        "db/migrate/20261010000002_add_action_and_export_scope_to_recording_studio_downloadable_packages.rb"
      )
    )

    assert_includes migration, "export_scope = COALESCE(export_scope, 'public')"
    assert_includes migration, "default_action_for"
    assert_includes migration, "idx_rs_downloadable_packages_identity"
    assert_includes ActiveRecord::Base.connection.indexes("recording_studio_downloadable_packages").map(&:name),
                    "idx_rs_downloadable_packages_identity"

    perform_enqueued_jobs { @recording.downloadable_generate!(action: :"workspaces.download", export_scope: :public) }
    package = RecordingStudioDownloadable::Package.find_by!(recording: @recording, format: "zip")

    assert_equal "workspaces.download", package.action
    assert_equal "public", package.export_scope
  end

  test "legacy lookup by recording and format still finds the default-action public package" do
    perform_enqueued_jobs { @recording.downloadable_generate! }

    found = RecordingStudioDownloadable::Package.find_by(
      recording_id: @recording.id,
      action: @recording.downloadable_action.to_s,
      export_scope: "public",
      format: "zip"
    )

    assert_equal @recording.downloadable_package.id, found.id
  end
end

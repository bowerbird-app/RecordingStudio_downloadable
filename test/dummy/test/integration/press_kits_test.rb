# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"
require "zip"

class PressKitsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.find_or_create_by!(email: "press-kits-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in @user
    @workspace = Workspace.create!(name: "Press Kit Workspace #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @user)
    @press_kit = PressKit.create!(
      name: "Launch Press Kit",
      description: "Hello reporters",
      credits: "Ava Chen, photos"
    )
    @recording = RecordingStudio.record!(
      action: "created",
      recordable: @press_kit,
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    attach_text!(@recording, filename: "logo.txt", contents: "studio mark")
  end

  test "press kits index lists kits with upload attachments download and edit" do
    get press_kits_path

    assert_response :success
    assert_select "h1", text: "Press kits"
    assert_includes response.body, "description.txt, credits.txt, and press-kit.json"
    assert_select "table td", text: "Launch Press Kit"
    assert_includes response.body, "Upload"
    assert_includes response.body, "Attachments"
    assert_includes response.body, "Edit"
    assert_includes response.body, recording_studio_downloadable.recording_package_path(@recording)
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_select "nav[aria-label='Main navigation']", count: 1
    assert_includes response.body, press_kits_path
  end

  test "workspace stays on attachments while press kits use a manifest" do
    assert_equal :attachments, @root.downloadable_source
    assert_equal :manifest, @recording.downloadable_source
  end

  test "downloading a press kit zip includes uploaded files and generated files" do
    names = @recording.downloadable_files.map(&:filename)

    assert_includes names, "logo.txt"
    assert_includes names, "description.txt"
    assert_includes names, "credits.txt"
    assert_includes names, "press-kit.json"

    perform_enqueued_jobs { @recording.downloadable_generate! }

    get recording_studio_downloadable.recording_package_path(@recording)

    assert_response :redirect
    follow_redirect!
    assert_response :success

    entries = zip_entries(response.body)
    assert_equal "studio mark", entries["logo.txt"]
    assert_equal "Hello reporters", entries["description.txt"]
    assert_equal "Ava Chen, photos", entries["credits.txt"]
    json = JSON.parse(entries.fetch("press-kit.json"))
    assert_equal "Launch Press Kit", json["name"]
    assert_equal "Hello reporters", json["description"]
    assert_includes json["files"], "logo.txt"
    assert_includes json["files"], "description.txt"
  end

  test "editing the description marks the package stale" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    assert @recording.reload.downloadable_ready?

    get edit_press_kit_path(@press_kit)
    assert_response :success
    assert_select "h1", text: "Edit description"
    assert_includes response.body, "press_kit[description]"

    patch press_kit_path(@press_kit), params: { press_kit: { description: "Hello world" } }

    assert_redirected_to press_kits_path
    @recording.reload
    refute @recording.downloadable_ready?
    assert_includes %w[pending processing], @recording.downloadable_package.state
    assert_equal "Hello world", @recording.recordable.description
  end

  private

  def attach_text!(parent_recording, filename:, contents:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(contents),
      filename: filename,
      content_type: "text/plain"
    )
    parent_recording.record_attachment_upload(
      signed_blob_id: blob.signed_id,
      actor: @user,
      name: File.basename(filename, ".*")
    )
  end

  def zip_entries(payload)
    entries = {}
    Zip::File.open_buffer(payload) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    entries
  end
end

# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PagesIndexTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "pages-index-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in @user
  end

  test "pages index lists page recordables in a table under the sidebar layout" do
    workspace = Workspace.create!(name: "Pages Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    page = Page.create!(title: "Smoke Page", description: "A short description for the table snippet.")
    RecordingStudio.record!(
      action: "created",
      recordable: page,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    get pages_path

    assert_response :success
    assert_select "h1", text: "Pages"
    assert_select "table", minimum: 1
    assert_select "table td", text: "Smoke Page"
    assert_select "table td", text: "A short description for the table snippet."
    assert_select "table td", text: "yes"
    assert_includes response.body, new_page_path
    assert_includes response.body, "Upload"
    assert_includes response.body, "Attachments"
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_select "nav[aria-label='Main navigation']", count: 1
    assert_includes response.body, pages_path
  end

  test "new page form renders under the sidebar layout" do
    get new_page_path

    assert_response :success
    assert_select "h1", text: "New page"
    assert_includes response.body, "page[title]"
    assert_includes response.body, "page[description]"
    assert_includes response.body, "flat-pack-sidebar-layout"
  end

  test "creating a page records it under the seeded folder and redirects to attachable upload" do
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.find_or_create_by!(name: "Product Docs")
    folder_recording = RecordingStudio::Recording.find_by(recordable: folder, trashed_at: nil) ||
      RecordingStudio.record!(
        action: "created",
        recordable: folder,
        root_recording: root_recording,
        parent_recording: root_recording
      ).recording

    title = "Created Page #{SecureRandom.hex(4)}"

    assert_difference -> { Page.count }, 1 do
      post pages_path, params: { page: { title: title, description: "From the new form." } }
    end

    page = Page.find_by!(title: title)
    recording = RecordingStudio::Recording.find_by!(recordable: page, trashed_at: nil)

    assert_equal folder_recording, recording.parent_recording
    assert recording.downloadable?
    assert_redirected_to recording_studio_attachable.recording_attachment_upload_path(recording)
  end
end

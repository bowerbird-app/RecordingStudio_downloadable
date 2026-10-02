# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PagesIndexTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "pages index lists page recordables under the sidebar layout" do
    user = User.find_or_create_by!(email: "pages-index-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Pages Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    page = Page.create!(title: "Smoke Page")
    RecordingStudio.record!(
      action: "created",
      recordable: page,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    get pages_path

    assert_response :success
    assert_select "h1", text: "Pages"
    assert_includes response.body, "Smoke Page"
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_select "nav[aria-label='Main navigation']", count: 1
    assert_includes response.body, pages_path
    assert_includes response.body, docs_recordings_tree_path
  end
end

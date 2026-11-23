# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio", "Access", "Accessible", ":edit", ":view", "permission", "role", "Admin"
  ].freeze
  ENABLED = %w[PressKit Workspace].freeze

  def test_tool_names_use_the_public_name
    assert_equal "download_press_kit", RecordingStudioDownloadable::McpCopy.tool_name_for("PressKit")
    assert_equal "download_press_kit", RecordingStudioDownloadable::McpCopy.tool_name_for("FeaturedIn::PressKit")
    assert_equal "PressKit", RecordingStudioDownloadable::McpCopy.public_type_name("FeaturedIn::PressKit")
    assert_equal "download_workspace", RecordingStudioDownloadable::McpCopy.tool_name_for("Workspace")

    with_enabled_types(ENABLED) do
      names = RecordingStudioDownloadable::McpCopy.tool_names
      assert_includes names, "download_press_kit"
      assert_includes names, "download_workspace"
      refute_includes names, "download"
      refute_includes names, "download_folder"
      refute_includes names, "download_recording"
      refute_includes names, "read_package_status"
      names.each do |name|
        assert_match(/\A[a-z][a-z0-9_]*\z/, name)
        refute_includes name, "RecordingStudio"
        refute_includes name, "FeaturedIn"
      end
    end
  end

  def test_mcp_version_floor_is_0_45
    assert RecordingStudioDownloadable::McpCopy.supported_mcp_version?("0.45")
    assert RecordingStudioDownloadable::McpCopy.supported_mcp_version?("0.45.2")
    refute RecordingStudioDownloadable::McpCopy.supported_mcp_version?("0.44.9")
  end

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    refute defined?(::RecordingStudioMcp)
    assert_nil RecordingStudioDownloadable::McpCopy.register!
  end

  def test_registration_calls_mcp_copy_after_the_api_actions
    source = File.read(
      File.expand_path("../lib/recording_studio_downloadable/api/registration.rb", __dir__)
    )

    assert_includes source, "McpCopy.register!"
    assert source.index("register_action") < source.index("McpCopy.register!")
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_downloadable.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_downloadable.rb", __dir__))

    refute_match(/add_dependency\s+"recording_studio_mcp"/, gemspec)
    refute_includes entry, 'require "recording_studio_mcp"'
  end

  def test_register_lists_one_download_tool_per_opted_in_type
    fake = RecordingMcp.new

    with_enabled_types(%w[PressKit Workspace]) do
      RecordingStudioDownloadable::McpCopy.stub(:mcp_available?, true) do
        RecordingStudioDownloadable::McpCopy.stub(:mcp, fake) do
          RecordingStudioDownloadable::McpCopy.register!
          RecordingStudioDownloadable::McpCopy.register!
        end
      end
    end

    assert_equal %w[download_press_kit download_workspace], fake.tools.keys.sort
    refute fake.tools.key?("download")
    refute fake.tools.key?("download_folder")
    refute fake.tools.key?("capability_action")
    refute fake.tools.key?("downloadable_download")
    refute fake.tools.key?("downloadable_package_status")
    refute fake.tools.key?("download_recording")
    refute fake.tools.key?("read_package_status")

    press_kit = fake.tools.fetch("download_press_kit")
    assert_equal :downloadable_download, press_kit[:action]
    assert_equal "PressKit", press_kit[:type]
    refute_equal "Download", press_kit[:type]
    refute press_kit.key?(:operation)
    assert_equal({ "id" => { description: "Recording id." } }, press_kit[:input])
    assert_includes press_kit[:description], "press kit"
    assert_includes press_kit[:description], "state, ready, stale"
    assert_includes press_kit[:description], "authorized package route"
    assert_includes press_kit[:description], "background"
    assert_includes press_kit[:description], "needs files"
    assert_includes press_kit[:output], "state, ready, stale, and failed"
    FORBIDDEN.each do |phrase|
      refute_includes press_kit[:description], phrase
      refute_includes press_kit[:title], phrase
    end
  end

  private

  def with_enabled_types(types, &)
    RecordingStudioDownloadable::McpCopy.stub(:downloadable_types, types, &)
  end

  class RecordingMcp
    attr_reader :tools

    def initialize
      @tools = {}
    end

    def register_tool(**registration)
      tools[registration.fetch(:name)] = registration
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio", "Access", "Accessible", ":edit", ":view", "permission", "role", "Admin"
  ].freeze

  def test_tool_names_are_verb_type_public_names
    assert_equal %w[download_recording read_package_status], RecordingStudioDownloadable::McpCopy.tool_names
    RecordingStudioDownloadable::McpCopy.tool_names.each do |name|
      assert_match(/\A[a-z][a-z0-9_]*\z/, name)
      refute_includes name, "RecordingStudio"
      refute_includes name, "downloadable_"
    end
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

  def test_register_lists_named_tools_and_rejects_generic_names
    fake = RecordingMcp.new

    RecordingStudioDownloadable::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioDownloadable::McpCopy.stub(:mcp, fake) do
        RecordingStudioDownloadable::McpCopy.register!
        RecordingStudioDownloadable::McpCopy.register!
      end
    end

    assert_equal %w[download_recording read_package_status], fake.tools.keys
    refute fake.tools.key?("capability_action")
    refute fake.tools.key?("downloadable_download")
    refute fake.tools.key?("downloadable_package_status")

    download = fake.tools.fetch("download_recording")
    status = fake.tools.fetch("read_package_status")
    assert_equal :downloadable_download, download[:action]
    assert_equal :downloadable_package_status, status[:action]
    refute download.key?(:type)
    refute status.key?(:type)
    refute download.key?(:operation)
    assert_equal RecordingStudioDownloadable::McpCopy::INPUT, download[:input]

    [download, status].each do |tool|
      assert_includes tool[:description], "state, ready, stale"
      assert_includes tool[:description], "authorized package route"
      assert_includes tool[:output], "state, ready, stale, and failed"
      FORBIDDEN.each do |phrase|
        refute_includes tool[:description], phrase
        refute_includes tool[:title], phrase
      end
    end
    assert_includes download[:description], "background"
    assert_includes download[:description], "needs files"
    assert_includes status[:description], "Does not start a build"
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

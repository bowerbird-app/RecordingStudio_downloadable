# frozen_string_literal: true

module RecordingStudioDownloadable
  # Named MCP tools for the download capability actions.
  # Hosts that do not load Recording Studio MCP keep the API and the package route.
  module McpCopy
    TOOLS = {
      "download_recording" => {
        action: :downloadable_download,
        title: "Download recording",
        description: "Request or build a ZIP of this recording's files. The ZIP is built in the " \
                     "background when it is not ready. Returns state, ready, stale, and failed. " \
                     "Does not return ZIP bytes or a URL. Fetch the file through the authorized " \
                     "package route when it is ready. The recording needs files. An empty source " \
                     "is not found. A download gate or a rate limit can refuse the request.",
        output: "Package status with state, ready, stale, and failed."
      },
      "read_package_status" => {
        action: :downloadable_package_status,
        title: "Read package status",
        description: "Read whether this recording's ZIP is ready. Returns state, ready, stale, " \
                     "and failed. Does not start a build. Does not return ZIP bytes or a URL. " \
                     "Fetch the file through the authorized package route when it is ready.",
        output: "Package status with state, ready, stale, and failed."
      }
    }.freeze
    INPUT = {
      "type" => { description: "Public name of the recordable type for this recording." },
      "id" => { description: "Recording id." }
    }.freeze

    module_function

    def register!
      return unless mcp_available?

      TOOLS.each_key { |name| register_tool(name) }
    end

    def tool_names
      TOOLS.keys
    end

    def mcp_available?
      defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:register_tool)
    end

    def mcp
      ::RecordingStudioMcp
    end

    def register_tool(name)
      spec = TOOLS.fetch(name)
      mcp.register_tool(
        name: name,
        action: spec.fetch(:action),
        title: spec.fetch(:title),
        description: spec.fetch(:description),
        input: INPUT,
        output: spec.fetch(:output)
      )
    end
    private_class_method :register_tool
  end
end

# frozen_string_literal: true

module RecordingStudioDownloadable
  # One named MCP tool per recordable that opted into Downloadable.
  # Hosts that do not load Recording Studio MCP keep the API and the package route.
  module McpCopy
    ACTION = :downloadable_download
    OUTPUT = "Package status with state, ready, stale, and failed."
    INPUT = {
      "id" => { description: "Recording id." }
    }.freeze

    module_function

    def register!
      return unless mcp_available?

      downloadable_types.each { |type_name| register_download_tool(type_name) }
    end

    def tool_names
      return [] unless mcp_available?

      downloadable_types.map { |type_name| ::RecordingStudioMcp.tool_name(type_name, :download) }
    end

    def downloadable_types
      return [] unless defined?(::RecordingStudio)

      RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
    end

    def mcp_available?
      defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:register_tool)
    end

    def register_download_tool(type_name)
      label = type_label(type_name)
      ::RecordingStudioMcp.register_tool(
        name: ::RecordingStudioMcp.tool_name(type_name, :download),
        type: type_name.to_s,
        action: ACTION,
        title: "Download #{label.downcase}",
        description: description_for(label),
        input: INPUT,
        output: OUTPUT
      )
    end
    private_class_method :register_download_tool

    def description_for(label)
      name = label.downcase
      "Request or build a ZIP of this #{name}. The ZIP is built in the background when it is not ready. " \
        "Returns state, ready, stale, and failed. Does not return ZIP bytes or a URL. " \
        "Fetch the file through the authorized package route when it is ready. " \
        "This #{name} needs files. An empty source is not found. " \
        "A download gate or a rate limit can refuse the request."
    end
    private_class_method :description_for

    def type_label(type_name)
      RecordingStudio.recordable_type_label(type_name)
    end
    private_class_method :type_label
  end
end

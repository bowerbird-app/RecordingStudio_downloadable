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
      downloadable_types.map { |type_name| tool_name_for(type_name) }
    end

    def tool_name_for(type_name)
      "download_#{public_type_name(type_name).underscore}"
    end

    def public_type_name(type_name)
      from_api = api_public_name(type_name)
      return from_api if from_api.present?

      type_name.to_s.demodulize
    end

    def downloadable_types
      return [] unless defined?(::RecordingStudio)

      load_recordable_types!
      RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
    end

    def mcp_available?
      return false unless defined?(::RecordingStudioMcp)
      return false unless ::RecordingStudioMcp.respond_to?(:register_tool)
      return false unless ::RecordingStudioMcp.const_defined?(:VERSION)

      supported_mcp_version?(::RecordingStudioMcp::VERSION)
    end

    def supported_mcp_version?(version)
      Gem::Version.new(version) >= Gem::Version.new("0.45")
    end

    def mcp
      ::RecordingStudioMcp
    end

    def register_download_tool(type_name)
      label = type_label(type_name)
      mcp.register_tool(
        name: tool_name_for(type_name),
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
      declaration = recordable_declaration(type_name)
      label = declaration.label if declaration.respond_to?(:label)
      return label if label.present?

      public_type_name(type_name).underscore.humanize
    end
    private_class_method :type_label

    def recordable_declaration(type_name)
      return unless defined?(::RecordingStudio)
      return unless ::RecordingStudio.respond_to?(:recordable_declaration_for)

      ::RecordingStudio.recordable_declaration_for(type_name)
    end
    private_class_method :recordable_declaration

    def api_public_name(type_name)
      return unless defined?(::RecordingStudioApi)
      return unless ::RecordingStudioApi.respond_to?(:recordable_registration_for)

      ::RecordingStudioApi.recordable_registration_for(type_name)&.public_name
    end
    private_class_method :api_public_name

    def load_recordable_types!
      declarations = RecordingStudio::RecordableDeclarations
      declarations.ensure_loaded! if declarations.respond_to?(:ensure_loaded!)
    end
    private_class_method :load_recordable_types!
  end
end

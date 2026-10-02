# frozen_string_literal: true

module RecordingStudioDownloadable
  class Configuration
    ROLE_ALIASES = {
      viewer: :view,
      editor: :edit,
      viewing: :view,
      editing: :edit
    }.freeze

    attr_accessor :authorize_with
    attr_reader :hooks, :auth_roles

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @authorize_with = nil
      @auth_roles = default_auth_roles
    end

    def auth_roles=(roles)
      @auth_roles = normalize_auth_roles(roles)
    end

    def auth_role_for(action)
      auth_roles.fetch(action.to_sym)
    end

    def normalize_role(role)
      return if role.nil?

      normalized = role.to_s.downcase.to_sym
      ROLE_ALIASES.fetch(normalized, normalized)
    end

    def normalize_auth_roles(roles)
      roles.to_h.transform_keys(&:to_sym).transform_values { |role| normalize_role(role) }
    end

    def to_h
      {
        auth_roles: auth_roles,
        authorize_with: authorize_with,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        merge_attribute!(key, value)
      end
    end

    private

    def default_auth_roles
      normalize_auth_roles(download: :view)
    end

    def merge_attribute!(key, value)
      setter = "#{key}="
      public_send(setter, merge_value(key, value)) if respond_to?(setter)
    end

    def merge_value(key, value)
      key.to_sym == :auth_roles ? normalize_auth_roles(value) : value
    end
  end
end

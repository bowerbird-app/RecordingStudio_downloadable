# frozen_string_literal: true

module RecordingStudioDownloadable
  class Configuration
    ROLE_ALIASES = {
      viewer: :view,
      editor: :edit,
      viewing: :view,
      editing: :edit
    }.freeze

    DEFAULT_SKIP_HOST_BEFORE_ACTIONS = %i[
      authenticate_user!
      authenticate_actor!
      authenticate!
      require_login
      require_user
      require_authentication
      set_current_actor
      set_tenant
      load_tenant
      require_tenant
      set_current_tenant
      set_current_workspace
      load_current_workspace
      require_workspace
    ].freeze

    attr_accessor :authorize_with, :cache, :max_zip_bytes, :max_concurrent_builds
    attr_reader :hooks, :auth_roles, :rate_limits, :content_change_debounce, :skip_host_before_actions

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @authorize_with = nil
      @auth_roles = default_auth_roles
      @rate_limits = default_rate_limits
      @max_zip_bytes = 500 * 1024 * 1024
      @max_concurrent_builds = 5
      @content_change_debounce = 45.seconds
      @skip_host_before_actions = DEFAULT_SKIP_HOST_BEFORE_ACTIONS.dup
      @cache = nil
    end

    def auth_roles=(roles)
      @auth_roles = normalize_auth_roles(roles)
    end

    def rate_limits=(value)
      @rate_limits = default_rate_limits.deep_merge(normalize_rate_limits(value))
    end

    def content_change_debounce=(value)
      @content_change_debounce = value.nil? ? 45.seconds : value
    end

    def skip_host_before_actions=(value)
      @skip_host_before_actions = Array(value).map(&:to_sym)
    end

    def auth_role_for(action)
      auth_roles[action.to_sym] || auth_roles[:download]
    end

    def normalize_role(role)
      return if role.nil?

      normalized = role.to_s.downcase.to_sym
      ROLE_ALIASES.fetch(normalized, normalized)
    end

    def normalize_auth_roles(roles)
      roles.to_h.transform_keys(&:to_sym).transform_values { |role| normalize_role(role) }
    end

    def cache_store
      cache || (defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : nil)
    end

    def debounce_wait
      wait = content_change_debounce
      return 45.seconds if wait.blank?

      seconds = wait.respond_to?(:to_f) ? wait.to_f : 45
      seconds = 45 if seconds <= 0
      seconds = 30 if seconds < 30
      seconds = 60 if seconds > 60
      seconds.seconds
    end

    def to_h
      {
        auth_roles: auth_roles,
        authorize_with: authorize_with,
        rate_limits: rate_limits,
        max_zip_bytes: max_zip_bytes,
        max_concurrent_builds: max_concurrent_builds,
        content_change_debounce: content_change_debounce,
        skip_host_before_actions: skip_host_before_actions,
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

    def default_rate_limits
      {
        ip: { limit: 60, period: 1.minute },
        actor: { limit: 60, period: 1.minute },
        recording: { limit: 30, period: 1.minute }
      }
    end

    def normalize_rate_limits(value)
      value.to_h.each_with_object({}) do |(key, settings), memo|
        memo[key.to_sym] = settings.to_h.symbolize_keys
      end
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

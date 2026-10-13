# frozen_string_literal: true

module RecordingStudioDownloadable
  # Thin adapter over {RecordingStudioCache::RateLimiter}. Public methods, config
  # keys, and cache key shapes stay as before. Counter keys now also receive a TTL
  # equal to the period (shared rails_cache backend).
  class RateLimiter
    class << self
      def throttle!(action:, ip:, actor:, recording:)
        settings = RecordingStudioDownloadable.configuration.rate_limits
        throttle_bucket!(:ip, key: ip.presence || "unknown", action: action, **limit_period(settings[:ip]))
        throttle_bucket!(:actor, key: actor_key(actor), action: action, **limit_period(settings[:actor]))
        throttle_bucket!(:recording, key: recording&.id, action: action, **limit_period(settings[:recording]))
      end

      def allowed?(action:, ip:, actor:, recording:)
        throttle!(action: action, ip: ip, actor: actor, recording: recording)
        true
      rescue RateLimitedError
        false
      end

      def concurrent_builds_for(action:)
        Package.where(state: %w[pending processing], action: action.to_s).count
      end

      def assert_concurrent_capacity!(action:, package: nil)
        max = RecordingStudioDownloadable.configuration.max_concurrent_builds
        return true if max.blank? || max.to_i <= 0
        return true if package&.persisted? && (package.pending? || package.processing?)

        count = concurrent_builds_for(action: action)
        return true if count < max.to_i

        raise ConcurrentBuildLimitError, Copy.t("errors.concurrent_builds", default: Copy::CONCURRENT_BUILDS)
      end

      private

      def throttle_bucket!(bucket, key:, action:, limit:, period:)
        # Same order as main: disable on blank / non-positive limit, then blank key.
        return true if limit.blank? || limit.to_i <= 0
        return true if key.blank?

        cache = RecordingStudioDownloadable.configuration.cache_store
        return true unless cache

        # Normalize like main's window math (`[period.to_i, 1].max`) before the
        # shared limiter, which rejects non-positive periods.
        result = RecordingStudioCache::RateLimiter.new(
          key: "#{action}:#{bucket}:#{key}",
          limit: limit.to_i,
          period: [period.to_i, 1].max,
          backend: :rails_cache,
          strategy: :fixed,
          store: cache,
          fail_closed: false,
          rescue_errors: [StandardError],
          prefix: "rs_downloadable:rate",
          separator: ":"
        ).throttle

        return true if result.allowed?

        raise RateLimitedError, Copy.t("errors.rate_limited", default: Copy::RATE_LIMITED)
      end

      def limit_period(settings)
        config = settings.to_h.symbolize_keys
        {
          limit: config[:limit],
          period: config[:period] || 1.minute
        }
      end

      def actor_key(actor)
        return "anonymous" if actor.blank?
        return actor.to_gid_param if actor.respond_to?(:to_gid_param)

        "#{actor.class.name}:#{actor.id}"
      rescue StandardError
        "anonymous"
      end
    end
  end
end

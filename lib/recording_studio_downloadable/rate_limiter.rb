# frozen_string_literal: true

module RecordingStudioDownloadable
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

        raise ConcurrentBuildLimitError, Copy.t("errors.concurrent_builds")
      end

      private

      def throttle_bucket!(bucket, key:, action:, limit:, period:)
        return true if limit.blank? || limit.to_i <= 0
        return true if key.blank?

        cache = RecordingStudioDownloadable.configuration.cache_store
        return true unless cache_usable?(cache)

        window = Time.now.to_i / [period.to_i, 1].max
        cache_key = ["rs_downloadable", "rate", action, bucket, key, window].join(":")
        count = increment(cache, cache_key, period)
        return true if count <= limit.to_i

        raise RateLimitedError, Copy.t("errors.rate_limited")
      end

      def increment(cache, key, period)
        count = cache.increment(key, 1)
        if count.nil?
          cache.write(key, 1, expires_in: period)
          1
        else
          count
        end
      rescue StandardError
        0
      end

      def cache_usable?(cache)
        cache.respond_to?(:increment) && cache.respond_to?(:write) &&
          !null_store?(cache)
      end

      def null_store?(cache)
        cache.class.name.to_s.include?("NullStore")
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

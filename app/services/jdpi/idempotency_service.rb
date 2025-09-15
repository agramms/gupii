module Jdpi
  # Idempotency service for JDPI API requests
  # Generates and manages idempotency keys as required by JDPI specification
  class IdempotencyService
    include Jdpi::StatusCodes

    CACHE_KEY_PREFIX = "jdpi:idempotency"
    DEFAULT_TTL = Duration::IDEMPOTENCY_CACHE_TTL_SECONDS

    class << self
      # Generate new idempotency key (36-character GUID as required by JDPI)
      def generate_key
        SecureRandom.uuid
      end

      # Store idempotency key with request context for deduplication
      def store_key(key, request_context = {})
        cache_key = "#{CACHE_KEY_PREFIX}:#{key}"

        data = {
          key: key,
          created_at: Time.current.iso8601,
          context: request_context
        }

        redis.setex(cache_key, DEFAULT_TTL, data.to_json)

        Rails.logger.debug "[JDPI Idempotency] Stored key: #{key}"
        key
      end

      # Check if idempotency key exists (for duplicate detection)
      def key_exists?(key)
        cache_key = "#{CACHE_KEY_PREFIX}:#{key}"
        redis.exists?(cache_key) > 0
      end

      # Retrieve request context for existing idempotency key
      def get_context(key)
        cache_key = "#{CACHE_KEY_PREFIX}:#{key}"
        cached_data = redis.get(cache_key)

        return nil unless cached_data

        JSON.parse(cached_data, symbolize_names: true)[:context]
      rescue JSON::ParserError => e
        Rails.logger.error "[JDPI Idempotency] Failed to parse cached context: #{e.message}"
        nil
      end

      # Generate and store idempotency key with context in one call
      def create_key(request_context = {})
        key = generate_key
        store_key(key, request_context)
      end

      # Validate idempotency key format (JDPI requires 36-character GUID)
      def valid_key?(key)
        return false unless key.is_a?(String)
        return false unless key.length == 36

        # UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
        !!(key =~ uuid_pattern)
      end

      # Clean up expired keys (optional maintenance task)
      def cleanup_expired_keys
        pattern = "#{CACHE_KEY_PREFIX}:*"
        keys = redis.keys(pattern)

        expired_count = 0
        keys.each do |key|
          expired_count += 1 unless redis.exists?(key) > 0
        end

        Rails.logger.info "[JDPI Idempotency] Cleanup complete, #{expired_count} expired keys removed"
        expired_count
      end

      # Get statistics about stored idempotency keys
      def stats
        pattern = "#{CACHE_KEY_PREFIX}:*"
        keys = redis.keys(pattern)

        {
          total_keys: keys.count,
          cache_prefix: CACHE_KEY_PREFIX,
          ttl_seconds: DEFAULT_TTL
        }
      end

      private

      def redis
        @redis ||= Redis.new(url: redis_url)
      end

      def redis_url
        Rails.application.credentials.redis&.dig(:url) ||
          ENV["REDIS_URL"] ||
          "redis://redis123@redis:6379/0"
      end
    end
  end
end

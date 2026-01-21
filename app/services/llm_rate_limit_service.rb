class LlmRateLimitService
  REDIS_KEY = "groq:llm_rate_limits"
  DAILY_USAGE_KEY = "groq:daily_token_usage"

  TOKEN_REQUIREMENTS = {
    'recruiter-writer' => 7000,
    'recruiter-simple' => 3500
  }.freeze

  DAILY_TOKEN_LIMIT = 95_000

  class InsufficientTokensError < StandardError
    attr_reader :wait_seconds
    def initialize(msg, wait_seconds: 60)
      @wait_seconds = wait_seconds
      super(msg)
    end
  end

  class DailyLimitExceededError < StandardError; end
  class ServiceUnavailableError < StandardError; end

  def initialize
    @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  end

  # Check if we can proceed with the given prompt type
  # Raises errors if cannot proceed
  def check_availability!(prompt_type)
    required_tokens = TOKEN_REQUIREMENTS[prompt_type]
    raise ArgumentError, "Unknown prompt type: #{prompt_type}" unless required_tokens

    # Check daily limit first
    check_daily_limit!(required_tokens)

    stored = fetch_stored_limits

    # No stored data - fetch from API and store
    if stored.nil?
      fetch_and_store_limits!
      stored = fetch_stored_limits
    end

    # If still nil after fetch attempt, block request (Redis or API failed)
    if stored.nil?
      raise ServiceUnavailableError, "Unable to verify rate limits. Please try again later."
    end

    remaining = stored[:remaining_tokens].to_i
    stored_at = stored[:stored_at].to_i
    reset_seconds = parse_reset_time(stored[:reset_tokens])

    # Check if reset has occurred
    reset_time = stored_at + reset_seconds
    if Time.now.to_i >= reset_time
      return true  # Reset happened, allow request
    end

    # Check if we have enough tokens
    if remaining >= required_tokens
      return true
    end

    # Not enough tokens
    wait_seconds = [reset_time - Time.now.to_i, 0].max
    raise InsufficientTokensError.new(
      "Insufficient tokens. Need #{required_tokens}, have #{remaining}. Please wait #{wait_seconds} seconds and try again.",
      wait_seconds: wait_seconds
    )
  end

  # Check if daily token limit would be exceeded
  def check_daily_limit!(required_tokens)
    daily_usage = fetch_daily_usage
    projected_usage = daily_usage + required_tokens

    if projected_usage > DAILY_TOKEN_LIMIT
      remaining = DAILY_TOKEN_LIMIT - daily_usage
      raise DailyLimitExceededError, "Daily token limit reached (#{daily_usage}/#{DAILY_TOKEN_LIMIT} used). #{remaining >= 0 ? "Only #{remaining} tokens remaining." : "Limit exceeded."} Resets at midnight UTC."
    end
  end

  # Store rate limits from API response
  def store_limits(rate_limits)
    return if rate_limits.nil?

    data = {
      remaining_tokens: rate_limits[:remaining_tokens],
      limit_tokens: rate_limits[:limit_tokens],
      reset_tokens: rate_limits[:reset_tokens],
      stored_at: Time.now.to_i
    }

    @redis.hset(REDIS_KEY, data.transform_keys(&:to_s))
    @redis.expire(REDIS_KEY, 7200)  # 2 hour TTL
    Rails.logger.info("LlmRateLimitService: Stored limits - remaining: #{data[:remaining_tokens]}")
  rescue Redis::BaseError => e
    Rails.logger.error("LlmRateLimitService Redis error: #{e.message}")
  end

  # Fetch from API and store
  def fetch_and_store_limits!
    limits = LlmService.check_rate_limits
    if limits[:error]
      Rails.logger.error("LlmRateLimitService API error: #{limits[:error]}")
      return
    end
    store_limits(limits)
  rescue StandardError => e
    Rails.logger.error("LlmRateLimitService fetch error: #{e.message}")
  end

  def fetch_stored_limits
    data = @redis.hgetall(REDIS_KEY)
    return nil if data.empty?
    data.transform_keys(&:to_sym)
  rescue Redis::BaseError => e
    Rails.logger.error("LlmRateLimitService Redis error: #{e.message}")
    nil  # Will cause ServiceUnavailableError to be raised
  end

  # Track token usage for the day
  def track_daily_usage(token_usage)
    return if token_usage.nil?

    total_tokens = token_usage[:total_tokens].to_i
    return if total_tokens <= 0

    today_key = daily_usage_key
    @redis.incrby(today_key, total_tokens)
    # Set TTL to expire at end of day UTC (max 24 hours + buffer)
    @redis.expire(today_key, seconds_until_midnight_utc + 3600)

    Rails.logger.info("LlmRateLimitService: Tracked #{total_tokens} tokens for daily usage")
  rescue Redis::BaseError => e
    Rails.logger.error("LlmRateLimitService Redis error tracking daily usage: #{e.message}")
  end

  # Get current daily usage
  def fetch_daily_usage
    usage = @redis.get(daily_usage_key)
    usage.to_i
  rescue Redis::BaseError => e
    Rails.logger.error("LlmRateLimitService Redis error fetching daily usage: #{e.message}")
    0  # Return 0 if we can't read, allow request to proceed
  end

  # Get daily usage info for health endpoint
  def fetch_daily_usage_info
    usage = fetch_daily_usage
    {
      tokens_used: usage,
      tokens_limit: DAILY_TOKEN_LIMIT,
      tokens_remaining: [DAILY_TOKEN_LIMIT - usage, 0].max,
      date: Time.now.utc.strftime('%Y-%m-%d'),
      resets_at: midnight_utc.iso8601,
      seconds_until_reset: seconds_until_midnight_utc
    }
  end

  private

  def daily_usage_key
    "#{DAILY_USAGE_KEY}:#{Time.now.utc.strftime('%Y-%m-%d')}"
  end

  def midnight_utc
    tomorrow = Time.now.utc.to_date + 1
    Time.utc(tomorrow.year, tomorrow.month, tomorrow.day)
  end

  def seconds_until_midnight_utc
    (midnight_utc - Time.now.utc).to_i
  end

  # Parse duration strings like "1m30s", "45s", "185ms" to seconds
  # Examples:
  #   "1m30s"  -> 90
  #   "45s"    -> 45
  #   "185ms"  -> 1 (rounds up)
  #   "500ms"  -> 1
  def parse_reset_time(reset_string)
    return 60 if reset_string.nil? || reset_string.empty?

    seconds = 0

    # Parse minutes (must check before 'ms' to avoid confusion)
    if reset_string =~ /(\d+)m(?!s)/  # 'm' not followed by 's'
      seconds += $1.to_i * 60
    end

    # Parse seconds (but not milliseconds - 's' not preceded by 'm')
    if reset_string =~ /(\d+(?:\.\d+)?)s(?<!ms)/
      seconds += $1.to_f.ceil
    end

    # Parse milliseconds and convert to seconds (round up)
    if reset_string =~ /(\d+)ms/
      ms = $1.to_i
      seconds += (ms / 1000.0).ceil
      seconds = 1 if seconds == 0 && ms > 0  # At least 1 second for any ms value
    end

    seconds > 0 ? seconds : 1  # Default to 1 second instead of 60
  end
end

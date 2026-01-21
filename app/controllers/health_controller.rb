class HealthController < ApplicationController
  # GET /health - Basic health check (no API calls)
  def show
    redis_status = check_redis
    groq_status, groq_model = check_groq

    all_healthy = redis_status && groq_status
    status = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? "healthy" : "unhealthy",
      timestamp: Time.current.iso8601,
      services: {
        redis: redis_status ? "connected" : "disconnected",
        groq: {
          status: groq_status ? "connected" : "disconnected",
          model: groq_model
        }
      }
    }, status: status
  end

  private

  def check_redis
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    redis.ping == "PONG"
  rescue StandardError
    false
  end

  def check_groq
    model = ENV.fetch("GROQ_MODEL", "llama-3.3-70b-versatile")
    api_key = ENV.fetch("GROQ_API_KEY", nil)
    # Just check if API key is configured (don't waste tokens on health checks)
    [ api_key.present?, model ]
  end

  public

  # GET /health/rate_limits - Check Groq API rate limits (uses ~1 token)
  def rate_limits
    limits = LlmService.check_rate_limits

    render json: {
      timestamp: Time.current.iso8601,
      model: ENV.fetch("GROQ_MODEL", "llama-3.3-70b-versatile"),
      rate_limits: {
        tokens: {
          remaining: limits[:remaining_tokens],
          limit: limits[:limit_tokens],
          resets_at: limits[:reset_tokens]
        },
        requests: {
          remaining: limits[:remaining_requests],
          limit: limits[:limit_requests],
          resets_at: limits[:reset_requests]
        }
      },
      error: limits[:error]
    }
  end

  # GET /health/llm_rate_limits - Show stored LLM rate limits from Redis (no API call)
  def llm_rate_limits
    service = LlmRateLimitService.new
    stored = service.fetch_stored_limits
    daily_usage = service.fetch_daily_usage_info

    if stored.nil?
      render json: {
        timestamp: Time.current.iso8601,
        stored: false,
        message: "No rate limits stored in Redis. Make an LLM request first.",
        daily_usage: daily_usage
      }
    else
      stored_at = Time.at(stored[:stored_at].to_i)
      reset_seconds = service.send(:parse_reset_time, stored[:reset_tokens])
      reset_at = stored_at + reset_seconds
      reset_happened = Time.now >= reset_at

      render json: {
        timestamp: Time.current.iso8601,
        stored: true,
        data: {
          remaining_tokens: stored[:remaining_tokens],
          limit_tokens: stored[:limit_tokens],
          reset_tokens: stored[:reset_tokens],
          stored_at: stored_at.iso8601,
          reset_at: reset_at.iso8601,
          reset_happened: reset_happened,
          seconds_until_reset: reset_happened ? 0 : (reset_at - Time.now).to_i
        },
        daily_usage: daily_usage
      }
    end
  end
end

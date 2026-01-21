class Rack::Attack
  # Use Redis for caching
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))

  # Throttle LLM requests: 10 requests per 5 minutes per IP
  throttle("llm/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path == "/llm/submit" && req.post?
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "text/html", "Retry-After" => retry_after.to_s },
      ["Too many requests. Please wait before trying again."]
    ]
  end
end

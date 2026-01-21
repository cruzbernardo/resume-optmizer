# Service class to handle LLM API calls via Groq
# Uses direct HTTP for full control over timeouts and behavior
class LlmService
  require 'net/http'
  require 'json'

  API_URL = 'https://api.groq.com/openai/v1/chat/completions'.freeze
  DEFAULT_MAX_TOKENS = 1000
  DEFAULT_TIMEOUT = 60  # seconds

  def initialize(model_id: nil, max_tokens: DEFAULT_MAX_TOKENS, timeout: DEFAULT_TIMEOUT)
    @model_id = model_id || ENV.fetch('GROQ_MODEL', 'llama-3.3-70b-versatile')
    @max_tokens = max_tokens
    @timeout = timeout
  end

  # Makes a chat completion request to the LLM
  #
  # @param system_prompt [String] Instructions that define HOW the LLM should behave
  # @param user_message [String] The actual content/question from the user
  # @return [Hash] { content: String, rate_limits: Hash }
  def chat(system_prompt:, user_message:)
    messages = [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_message }
    ]

    response = make_request(messages: messages, max_tokens: @max_tokens)

    Rails.logger.info("LLM Response Code: #{response.code}")
    Rails.logger.info("LLM Response Body: #{response.body[0..500]}...")

    # Parse response and extract content
    body = JSON.parse(response.body)

    if response.code.to_i != 200
      error_msg = body.dig('error', 'message') || "HTTP #{response.code}"
      raise LlmServiceError, error_msg
    end

    content = body.dig('choices', 0, 'message', 'content')
    Rails.logger.info("LLM Content extracted: #{content ? content[0..200] : 'NIL'}...")

    # Extract token usage from response body
    usage = body['usage'] || {}
    token_usage = {
      prompt_tokens: usage['prompt_tokens'] || 0,
      completion_tokens: usage['completion_tokens'] || 0,
      total_tokens: usage['total_tokens'] || 0
    }
    Rails.logger.info("LLM Token usage: #{token_usage}")

    {
      content: content,
      rate_limits: extract_rate_limits(response),
      token_usage: token_usage
    }
  rescue JSON::ParserError => e
    Rails.logger.error("LLM Service JSON Error: #{e.message}")
    raise LlmServiceError, "Invalid response from API"
  rescue StandardError => e
    Rails.logger.error("LLM Service Error: #{e.message}")
    raise LlmServiceError, e.message
  end

  # Check rate limits by making a minimal API call
  # Returns hash with remaining tokens/requests info
  def self.check_rate_limits
    uri = URI(API_URL)
    http = build_http(uri, timeout: 10)

    request = build_request(uri, {
      model: ENV.fetch('GROQ_MODEL', 'llama-3.3-70b-versatile'),
      messages: [{ role: 'user', content: 'hi' }],
      max_tokens: 1
    })

    response = http.request(request)

    {
      remaining_requests: response['x-ratelimit-remaining-requests'],
      remaining_tokens: response['x-ratelimit-remaining-tokens'],
      reset_requests: response['x-ratelimit-reset-requests'],
      reset_tokens: response['x-ratelimit-reset-tokens'],
      limit_requests: response['x-ratelimit-limit-requests'],
      limit_tokens: response['x-ratelimit-limit-tokens']
    }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def make_request(messages:, max_tokens:)
    uri = URI(API_URL)
    http = self.class.build_http(uri, timeout: @timeout)

    request = self.class.build_request(uri, {
      model: @model_id,
      messages: messages,
      max_tokens: max_tokens
    })

    http.request(request)
  end

  def self.build_http(uri, timeout:)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = timeout
    http.read_timeout = timeout
    http
  end

  def self.build_request(uri, body)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{ENV.fetch('GROQ_API_KEY', '')}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json
    request
  end

  def extract_rate_limits(response)
    {
      remaining_requests: response['x-ratelimit-remaining-requests'],
      remaining_tokens: response['x-ratelimit-remaining-tokens'],
      reset_requests: response['x-ratelimit-reset-requests'],
      reset_tokens: response['x-ratelimit-reset-tokens'],
      limit_requests: response['x-ratelimit-limit-requests'],
      limit_tokens: response['x-ratelimit-limit-tokens']
    }
  end

  class LlmServiceError < StandardError; end
end



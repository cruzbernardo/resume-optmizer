require 'rails_helper'

RSpec.describe LlmService do
  let(:service) { described_class.new }
  let(:api_url) { 'https://api.groq.com/openai/v1/chat/completions' }

  before do
    allow(ENV).to receive(:fetch).with('GROQ_API_KEY', '').and_return('test_api_key')
    allow(ENV).to receive(:fetch).with('GROQ_MODEL', 'llama-3.3-70b-versatile').and_return('llama-3.3-70b-versatile')
  end

  describe '#initialize' do
    it 'uses default model when not specified' do
      service = described_class.new
      expect(service.instance_variable_get(:@model_id)).to eq('llama-3.3-70b-versatile')
    end

    it 'uses custom model when specified' do
      service = described_class.new(model_id: 'custom-model')
      expect(service.instance_variable_get(:@model_id)).to eq('custom-model')
    end

    it 'uses default max_tokens of 1000' do
      service = described_class.new
      expect(service.instance_variable_get(:@max_tokens)).to eq(1000)
    end

    it 'uses custom max_tokens when specified' do
      service = described_class.new(max_tokens: 2000)
      expect(service.instance_variable_get(:@max_tokens)).to eq(2000)
    end

    it 'uses default timeout of 60 seconds' do
      service = described_class.new
      expect(service.instance_variable_get(:@timeout)).to eq(60)
    end
  end

  describe '#chat' do
    let(:system_prompt) { 'You are a helpful assistant' }
    let(:user_message) { 'Hello, world!' }
    let(:successful_response_body) do
      {
        'choices' => [
          { 'message' => { 'content' => 'Hello! How can I help you?' } }
        ],
        'usage' => {
          'prompt_tokens' => 10,
          'completion_tokens' => 8,
          'total_tokens' => 18
        }
      }.to_json
    end

    let(:mock_response) do
      response = instance_double(Net::HTTPResponse)
      allow(response).to receive(:code).and_return('200')
      allow(response).to receive(:body).and_return(successful_response_body)
      allow(response).to receive(:[]).with('x-ratelimit-remaining-requests').and_return('999')
      allow(response).to receive(:[]).with('x-ratelimit-remaining-tokens').and_return('14000')
      allow(response).to receive(:[]).with('x-ratelimit-reset-requests').and_return('1m30s')
      allow(response).to receive(:[]).with('x-ratelimit-reset-tokens').and_return('45s')
      allow(response).to receive(:[]).with('x-ratelimit-limit-requests').and_return('1000')
      allow(response).to receive(:[]).with('x-ratelimit-limit-tokens').and_return('15000')
      response
    end

    before do
      mock_http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:open_timeout=)
      allow(mock_http).to receive(:read_timeout=)
      allow(mock_http).to receive(:request).and_return(mock_response)
    end

    it 'returns content from successful response' do
      result = service.chat(system_prompt: system_prompt, user_message: user_message)
      expect(result[:content]).to eq('Hello! How can I help you?')
    end

    it 'returns rate limits from response headers' do
      result = service.chat(system_prompt: system_prompt, user_message: user_message)
      expect(result[:rate_limits]).to include(
        remaining_requests: '999',
        remaining_tokens: '14000',
        limit_tokens: '15000'
      )
    end

    it 'returns token usage from response body' do
      result = service.chat(system_prompt: system_prompt, user_message: user_message)
      expect(result[:token_usage]).to eq(
        prompt_tokens: 10,
        completion_tokens: 8,
        total_tokens: 18
      )
    end

    context 'when API returns error' do
      let(:error_response_body) do
        { 'error' => { 'message' => 'Rate limit exceeded' } }.to_json
      end

      let(:mock_error_response) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return('429')
        allow(response).to receive(:body).and_return(error_response_body)
        response
      end

      before do
        mock_http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_error_response)
      end

      it 'raises LlmServiceError with error message' do
        expect {
          service.chat(system_prompt: system_prompt, user_message: user_message)
        }.to raise_error(LlmService::LlmServiceError, 'Rate limit exceeded')
      end
    end

    context 'when response is invalid JSON' do
      let(:mock_invalid_response) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return('200')
        allow(response).to receive(:body).and_return('not valid json')
        response
      end

      before do
        mock_http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_invalid_response)
      end

      it 'raises LlmServiceError for invalid JSON' do
        expect {
          service.chat(system_prompt: system_prompt, user_message: user_message)
        }.to raise_error(LlmService::LlmServiceError, 'Invalid response from API')
      end
    end

    context 'when usage data is missing' do
      let(:response_without_usage) do
        {
          'choices' => [
            { 'message' => { 'content' => 'Hello!' } }
          ]
        }.to_json
      end

      let(:mock_response_no_usage) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return('200')
        allow(response).to receive(:body).and_return(response_without_usage)
        allow(response).to receive(:[]).and_return(nil)
        response
      end

      before do
        mock_http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_response_no_usage)
      end

      it 'returns zero token usage' do
        result = service.chat(system_prompt: system_prompt, user_message: user_message)
        expect(result[:token_usage]).to eq(
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0
        )
      end
    end
  end

  describe '.check_rate_limits' do
    let(:mock_response) do
      response = instance_double(Net::HTTPResponse)
      allow(response).to receive(:[]).with('x-ratelimit-remaining-requests').and_return('998')
      allow(response).to receive(:[]).with('x-ratelimit-remaining-tokens').and_return('14500')
      allow(response).to receive(:[]).with('x-ratelimit-reset-requests').and_return('2m')
      allow(response).to receive(:[]).with('x-ratelimit-reset-tokens').and_return('30s')
      allow(response).to receive(:[]).with('x-ratelimit-limit-requests').and_return('1000')
      allow(response).to receive(:[]).with('x-ratelimit-limit-tokens').and_return('15000')
      response
    end

    before do
      mock_http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:open_timeout=)
      allow(mock_http).to receive(:read_timeout=)
      allow(mock_http).to receive(:request).and_return(mock_response)
    end

    it 'returns rate limit information' do
      result = described_class.check_rate_limits
      expect(result).to include(
        remaining_requests: '998',
        remaining_tokens: '14500',
        reset_requests: '2m',
        reset_tokens: '30s',
        limit_requests: '1000',
        limit_tokens: '15000'
      )
    end

    context 'when request fails' do
      before do
        allow(Net::HTTP).to receive(:new).and_raise(StandardError, 'Connection refused')
      end

      it 'returns error hash' do
        result = described_class.check_rate_limits
        expect(result).to eq(error: 'Connection refused')
      end
    end
  end

  describe '.build_http' do
    it 'creates HTTP client with SSL enabled' do
      uri = URI('https://api.groq.com')
      http = described_class.build_http(uri, timeout: 30)

      expect(http).to be_a(Net::HTTP)
      expect(http.use_ssl?).to be true
    end

    it 'sets timeout values' do
      uri = URI('https://api.groq.com')
      http = described_class.build_http(uri, timeout: 45)

      expect(http.open_timeout).to eq(45)
      expect(http.read_timeout).to eq(45)
    end
  end

  describe '.build_request' do
    it 'creates POST request with correct headers' do
      uri = URI('https://api.groq.com/openai/v1/chat/completions')
      body = { model: 'test', messages: [] }

      request = described_class.build_request(uri, body)

      expect(request).to be_a(Net::HTTP::Post)
      expect(request['Content-Type']).to eq('application/json')
      expect(request['Authorization']).to eq('Bearer test_api_key')
    end

    it 'sets request body as JSON' do
      uri = URI('https://api.groq.com/openai/v1/chat/completions')
      body = { model: 'test', messages: [{ role: 'user', content: 'hi' }] }

      request = described_class.build_request(uri, body)
      parsed = JSON.parse(request.body)

      expect(parsed['model']).to eq('test')
      expect(parsed['messages']).to be_an(Array)
      expect(parsed['messages'].first['role']).to eq('user')
      expect(parsed['messages'].first['content']).to eq('hi')
    end
  end
end

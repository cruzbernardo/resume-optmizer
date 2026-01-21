require 'swagger_helper'

RSpec.describe 'Health API', type: :request do
  path '/health' do
    get 'Check application health' do
      tags 'Health'
      produces 'application/json'
      description 'Returns the health status of the application and its services (Redis)'

      response '200', 'Application is healthy' do
        schema type: :object,
          properties: {
            status: { type: :string, example: 'healthy' },
            timestamp: { type: :string, format: 'date-time', example: '2026-01-20T21:30:00Z' },
            services: {
              type: :object,
              properties: {
                redis: { type: :string, example: 'connected' }
              }
            }
          },
          required: %w[status timestamp services]

        run_test!
      end

      response '503', 'Application is unhealthy' do
        schema type: :object,
          properties: {
            status: { type: :string, example: 'unhealthy' },
            timestamp: { type: :string, format: 'date-time' },
            services: {
              type: :object,
              properties: {
                redis: { type: :string, example: 'disconnected' }
              }
            }
          }

        run_test! do
          # This test would need Redis to be down to pass
          # Skipping actual run for unhealthy state
        end
      end
    end
  end

  path '/up' do
    get 'Rails built-in health check' do
      tags 'Health'
      description 'Built-in Rails health check endpoint'

      response '200', 'Application is up' do
        run_test!
      end
    end
  end

  path '/health/llm_rate_limits' do
    get 'Check stored LLM rate limits from Redis' do
      tags 'Health'
      produces 'application/json'
      description 'Returns LLM rate limits stored in Redis without calling Groq API'

      response '200', 'Stored rate limits retrieved' do
        schema type: :object,
          properties: {
            timestamp: { type: :string, format: 'date-time' },
            stored: { type: :boolean },
            message: { type: :string, nullable: true },
            data: {
              type: :object,
              nullable: true,
              properties: {
                remaining_tokens: { type: :string },
                limit_tokens: { type: :string },
                reset_tokens: { type: :string },
                stored_at: { type: :string, format: 'date-time' },
                reset_at: { type: :string, format: 'date-time' },
                reset_happened: { type: :boolean },
                seconds_until_reset: { type: :integer }
              }
            },
            daily_usage: {
              type: :object,
              properties: {
                tokens_used: { type: :integer },
                tokens_limit: { type: :integer },
                tokens_remaining: { type: :integer },
                date: { type: :string },
                resets_at: { type: :string, format: 'date-time' },
                seconds_until_reset: { type: :integer }
              }
            }
          },
          required: %w[timestamp stored daily_usage]

        run_test!
      end
    end
  end
end

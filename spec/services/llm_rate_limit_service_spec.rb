require 'rails_helper'

RSpec.describe LlmRateLimitService do
  let(:service) { described_class.new }
  let(:redis) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(redis)
    allow(redis).to receive(:hgetall).and_return({})
    allow(redis).to receive(:hset)
    allow(redis).to receive(:expire)
    allow(redis).to receive(:get).and_return(nil)
    allow(redis).to receive(:incrby)
  end

  describe 'constants' do
    it 'defines REDIS_KEY' do
      expect(described_class::REDIS_KEY).to eq('groq:llm_rate_limits')
    end

    it 'defines DAILY_USAGE_KEY' do
      expect(described_class::DAILY_USAGE_KEY).to eq('groq:daily_token_usage')
    end

    it 'defines TOKEN_REQUIREMENTS' do
      expect(described_class::TOKEN_REQUIREMENTS).to eq({
        'recruiter-writer' => 7000,
        'recruiter-simple' => 3500
      })
    end

    it 'defines DAILY_TOKEN_LIMIT' do
      expect(described_class::DAILY_TOKEN_LIMIT).to eq(95_000)
    end
  end

  describe '#check_availability!' do
    context 'with unknown prompt type' do
      it 'raises ArgumentError' do
        expect {
          service.check_availability!('unknown-type')
        }.to raise_error(ArgumentError, 'Unknown prompt type: unknown-type')
      end
    end

    context 'when daily limit is exceeded' do
      before do
        allow(redis).to receive(:get).and_return('93000')
      end

      it 'raises DailyLimitExceededError for recruiter-writer' do
        expect {
          service.check_availability!('recruiter-writer')
        }.to raise_error(described_class::DailyLimitExceededError, /Daily token limit reached/)
      end
    end

    context 'when no stored limits exist' do
      before do
        allow(redis).to receive(:hgetall).and_return({})
        allow(LlmService).to receive(:check_rate_limits).and_return({
          remaining_tokens: '15000',
          limit_tokens: '15000',
          reset_tokens: '60s'
        })
      end

      it 'fetches limits from API and stores them' do
        allow(redis).to receive(:hgetall).and_return(
          {},
          {
            'remaining_tokens' => '15000',
            'limit_tokens' => '15000',
            'reset_tokens' => '60s',
            'stored_at' => Time.now.to_i.to_s
          }
        )

        expect(LlmService).to receive(:check_rate_limits)
        expect(service.check_availability!('recruiter-simple')).to be true
      end
    end

    context 'when stored limits exist with enough tokens' do
      before do
        allow(redis).to receive(:hgetall).and_return({
          'remaining_tokens' => '10000',
          'limit_tokens' => '15000',
          'reset_tokens' => '60s',
          'stored_at' => Time.now.to_i.to_s
        })
      end

      it 'returns true for recruiter-simple' do
        expect(service.check_availability!('recruiter-simple')).to be true
      end

      it 'returns true for recruiter-writer' do
        expect(service.check_availability!('recruiter-writer')).to be true
      end
    end

    context 'when stored limits exist with insufficient tokens' do
      before do
        allow(redis).to receive(:hgetall).and_return({
          'remaining_tokens' => '3000',
          'limit_tokens' => '15000',
          'reset_tokens' => '60s',
          'stored_at' => Time.now.to_i.to_s
        })
      end

      it 'raises InsufficientTokensError for recruiter-writer' do
        expect {
          service.check_availability!('recruiter-writer')
        }.to raise_error(described_class::InsufficientTokensError, /Insufficient tokens/)
      end

      it 'returns true for recruiter-simple (3500 required, 3000 available but reset check)' do
        expect {
          service.check_availability!('recruiter-simple')
        }.to raise_error(described_class::InsufficientTokensError)
      end
    end

    context 'when reset time has passed' do
      before do
        allow(redis).to receive(:hgetall).and_return({
          'remaining_tokens' => '1000',
          'limit_tokens' => '15000',
          'reset_tokens' => '60s',
          'stored_at' => (Time.now.to_i - 120).to_s  # 2 minutes ago
        })
      end

      it 'returns true even with low tokens (reset happened)' do
        expect(service.check_availability!('recruiter-writer')).to be true
      end
    end

    context 'when Redis is unavailable after fetch attempt' do
      before do
        allow(redis).to receive(:hgetall).and_return({})
        allow(LlmService).to receive(:check_rate_limits).and_return({ error: 'Connection refused' })
      end

      it 'raises ServiceUnavailableError' do
        expect {
          service.check_availability!('recruiter-simple')
        }.to raise_error(described_class::ServiceUnavailableError, /Unable to verify rate limits/)
      end
    end
  end

  describe '#check_daily_limit!' do
    context 'when under daily limit' do
      before do
        allow(redis).to receive(:get).and_return('50000')
      end

      it 'does not raise error' do
        expect { service.check_daily_limit!(7000) }.not_to raise_error
      end
    end

    context 'when at daily limit' do
      before do
        allow(redis).to receive(:get).and_return('95000')
      end

      it 'raises DailyLimitExceededError' do
        expect {
          service.check_daily_limit!(1)
        }.to raise_error(described_class::DailyLimitExceededError)
      end
    end

    context 'when would exceed daily limit' do
      before do
        allow(redis).to receive(:get).and_return('90000')
      end

      it 'raises DailyLimitExceededError for large request' do
        expect {
          service.check_daily_limit!(7000)
        }.to raise_error(described_class::DailyLimitExceededError, /Daily token limit reached/)
      end
    end
  end

  describe '#store_limits' do
    it 'stores rate limits in Redis' do
      rate_limits = {
        remaining_tokens: '14000',
        limit_tokens: '15000',
        reset_tokens: '45s'
      }

      expect(redis).to receive(:hset).with(
        'groq:llm_rate_limits',
        hash_including(
          'remaining_tokens' => '14000',
          'limit_tokens' => '15000',
          'reset_tokens' => '45s'
        )
      )
      expect(redis).to receive(:expire).with('groq:llm_rate_limits', 7200)

      service.store_limits(rate_limits)
    end

    it 'does nothing when rate_limits is nil' do
      expect(redis).not_to receive(:hset)
      service.store_limits(nil)
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:hset).and_raise(Redis::BaseError, 'Connection lost')
      end

      it 'logs error and does not raise' do
        expect(Rails.logger).to receive(:error).with(/Redis error/)
        expect { service.store_limits({ remaining_tokens: '1000' }) }.not_to raise_error
      end
    end
  end

  describe '#fetch_stored_limits' do
    context 'when data exists' do
      before do
        allow(redis).to receive(:hgetall).and_return({
          'remaining_tokens' => '14000',
          'limit_tokens' => '15000',
          'reset_tokens' => '30s',
          'stored_at' => '1737500000'
        })
      end

      it 'returns symbolized hash' do
        result = service.fetch_stored_limits
        expect(result).to eq({
          remaining_tokens: '14000',
          limit_tokens: '15000',
          reset_tokens: '30s',
          stored_at: '1737500000'
        })
      end
    end

    context 'when no data exists' do
      before do
        allow(redis).to receive(:hgetall).and_return({})
      end

      it 'returns nil' do
        expect(service.fetch_stored_limits).to be_nil
      end
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:hgetall).and_raise(Redis::BaseError, 'Connection lost')
      end

      it 'returns nil' do
        expect(service.fetch_stored_limits).to be_nil
      end
    end
  end

  describe '#track_daily_usage' do
    it 'increments daily usage counter' do
      today_key = "groq:daily_token_usage:#{Time.now.utc.strftime('%Y-%m-%d')}"

      expect(redis).to receive(:incrby).with(today_key, 150)
      expect(redis).to receive(:expire)

      service.track_daily_usage({ total_tokens: 150 })
    end

    it 'does nothing when token_usage is nil' do
      expect(redis).not_to receive(:incrby)
      service.track_daily_usage(nil)
    end

    it 'does nothing when total_tokens is zero' do
      expect(redis).not_to receive(:incrby)
      service.track_daily_usage({ total_tokens: 0 })
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:incrby).and_raise(Redis::BaseError, 'Connection lost')
      end

      it 'logs error and does not raise' do
        expect(Rails.logger).to receive(:error).with(/Redis error tracking daily usage/)
        expect { service.track_daily_usage({ total_tokens: 100 }) }.not_to raise_error
      end
    end
  end

  describe '#fetch_daily_usage' do
    context 'when usage exists' do
      before do
        allow(redis).to receive(:get).and_return('25000')
      end

      it 'returns usage as integer' do
        expect(service.fetch_daily_usage).to eq(25000)
      end
    end

    context 'when no usage exists' do
      before do
        allow(redis).to receive(:get).and_return(nil)
      end

      it 'returns 0' do
        expect(service.fetch_daily_usage).to eq(0)
      end
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:get).and_raise(Redis::BaseError, 'Connection lost')
      end

      it 'returns 0' do
        expect(service.fetch_daily_usage).to eq(0)
      end
    end
  end

  describe '#fetch_daily_usage_info' do
    before do
      allow(redis).to receive(:get).and_return('30000')
      allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 21, 12, 0, 0))
    end

    it 'returns complete daily usage info' do
      result = service.fetch_daily_usage_info

      expect(result[:tokens_used]).to eq(30000)
      expect(result[:tokens_limit]).to eq(95000)
      expect(result[:tokens_remaining]).to eq(65000)
      expect(result[:date]).to eq('2026-01-21')
      expect(result[:resets_at]).to eq('2026-01-22T00:00:00Z')
      expect(result[:seconds_until_reset]).to be > 0
    end
  end

  describe 'InsufficientTokensError' do
    it 'stores wait_seconds' do
      error = described_class::InsufficientTokensError.new('Not enough tokens', wait_seconds: 45)
      expect(error.wait_seconds).to eq(45)
      expect(error.message).to eq('Not enough tokens')
    end

    it 'defaults wait_seconds to 60' do
      error = described_class::InsufficientTokensError.new('Error')
      expect(error.wait_seconds).to eq(60)
    end
  end

  describe '#parse_reset_time (private)' do
    it 'parses minutes and seconds' do
      expect(service.send(:parse_reset_time, '1m30s')).to eq(90)
    end

    it 'parses seconds only' do
      expect(service.send(:parse_reset_time, '45s')).to eq(45)
    end

    it 'parses minutes only' do
      expect(service.send(:parse_reset_time, '2m')).to eq(120)
    end

    it 'parses milliseconds (rounds up to at least 1 second)' do
      expect(service.send(:parse_reset_time, '185ms')).to eq(1)
      expect(service.send(:parse_reset_time, '500ms')).to eq(1)
      expect(service.send(:parse_reset_time, '1500ms')).to eq(2)
    end

    it 'returns 60 for nil' do
      expect(service.send(:parse_reset_time, nil)).to eq(60)
    end

    it 'returns 60 for empty string' do
      expect(service.send(:parse_reset_time, '')).to eq(60)
    end

    it 'returns 1 for unparseable string' do
      expect(service.send(:parse_reset_time, 'invalid')).to eq(1)
    end
  end
end

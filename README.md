# Resume Optimizer

AI-powered resume optimization tool that tailors your resume to match job descriptions using Groq/Llama LLM.

## Features

- **Resume Analysis**: Get AI-powered suggestions to improve your resume
- **Resume Generation**: Generate a fully tailored resume based on job requirements
- **HTML Template**: Professional resume template with PDF export capability
- **Rate Limiting**: Redis-based token tracking (per-minute + daily limits)
- **Neobrutalism UI**: Modern design with Ruby Gem color theme

## Tech Stack

- **Ruby** 3.3.10
- **Rails** 8.1.2
- **Redis** - Rate limiting and token tracking
- **Tailwind CSS** - Styling with Neobrutalism design
- **Groq API** - LLM provider (Llama 3.3 70B)
- **rswag** - Swagger/OpenAPI documentation

## Prerequisites

- Ruby 3.3.10
- Redis server
- Groq API key (free tier available at https://console.groq.com)

## Setup

1. **Clone the repository**
   ```bash
   git clone git@github.com:cruzbernardo/resume-optimizer.git
   cd resume-optimizer
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

4. **Start Redis**
   ```bash
   redis-server
   # Or with Docker: docker run -d -p 6379:6379 redis
   ```

5. **Start the server**
   ```bash
   bin/rails server
   ```

6. **Access the application**
   - Home: http://localhost:3000
   - API Docs: http://localhost:3000/api-docs

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GROQ_API_KEY` | Your Groq API key (required) | - |
| `GROQ_MODEL` | LLM model to use | `llama-3.3-70b-versatile` |
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379/0` |

## Rate Limits

The application implements two levels of rate limiting:

1. **Per-minute tokens** (from Groq API headers)
   - Checks available tokens before each request
   - Blocks if insufficient tokens, shows wait time

2. **Daily token limit** (95,000 tokens)
   - Tracks cumulative daily usage in Redis
   - Resets at midnight UTC

3. **IP-based request limit** (Rack::Attack)
   - 10 requests per 5 minutes per IP

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Home page |
| `GET /llm/submit` | Resume optimization form |
| `POST /llm/submit` | Submit resume for optimization |
| `GET /llm/show` | HTML template page |
| `GET /health` | Application health check |
| `GET /health/rate_limits` | Groq API rate limits (uses ~1 token) |
| `GET /health/llm_rate_limits` | Stored rate limits from Redis |
| `GET /api-docs` | Swagger documentation |

## Testing

```bash
# Run all tests
bundle exec rspec

# Run tests with detailed output
bundle exec rspec --format documentation

# Run only service tests
bundle exec rspec spec/services/

# Run a specific test file
bundle exec rspec spec/services/llm_service_spec.rb
```

## Development

```bash
# Run with Docker Compose
docker-compose up

# Generate Swagger docs
bundle exec rake rswag:specs:swaggerize
```

## License

MIT

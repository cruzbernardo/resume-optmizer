class LlmController < ApplicationController
  RESUME_MAX_LENGTH = 6000
  JOB_DESCRIPTION_MAX_LENGTH = 7000

  def submit
    # GET - show the form
  end

  def create
    # POST - process the form
    @job_description = sanitize_input(params[:job_description])
    @resume = sanitize_input(params[:resume])
    @prompt_type = params[:prompt_type]

    # Validate character limits
    @errors = []
    if @resume.length > RESUME_MAX_LENGTH
      @errors << "Resume exceeds #{RESUME_MAX_LENGTH} characters (current: #{@resume.length})"
    end
    if @job_description.length > JOB_DESCRIPTION_MAX_LENGTH
      @errors << "Job description exceeds #{JOB_DESCRIPTION_MAX_LENGTH} characters (current: #{@job_description.length})"
    end

    if @errors.any?
      render :submit and return
    end

    # CHECK LLM RATE LIMITS BEFORE PROCEEDING
    llm_rate_limit_service = LlmRateLimitService.new
    llm_rate_limit_service.check_availability!(@prompt_type)

    # Load prompts
    prompts = YAML.load_file(Rails.root.join('config', 'prompts.yml'))
    system_prompt = prompts['system'][@prompt_type]

    # Build user message
    user_message = <<~MSG
      Job Description:
      #{@job_description}

      Resume Data:
      #{@resume}
    MSG

    # Add HTML template structure as reference for recruiter-writer
    if @prompt_type == 'recruiter-writer'
      user_message = <<~MSG
        HTML Template structure (use as reference for sections):
        #{Templates::RESUME_HTML}

        #{user_message}
      MSG
    end

    # Call Groq API via LlmService
    # Both prompt types now output plain text, using default tokens
    service = LlmService.new
    response = service.chat(system_prompt: system_prompt, user_message: user_message)
    @result = response[:content]

    # UPDATE REDIS WITH NEW LLM RATE LIMITS
    llm_rate_limit_service.store_limits(response[:rate_limits])

    # TRACK DAILY TOKEN USAGE
    llm_rate_limit_service.track_daily_usage(response[:token_usage])
  rescue LlmRateLimitService::InsufficientTokensError => e
    @errors = [e.message]
  rescue LlmRateLimitService::DailyLimitExceededError => e
    @errors = [e.message]
  rescue LlmRateLimitService::ServiceUnavailableError => e
    @errors = [e.message]
  rescue LlmService::LlmServiceError => e
    @result = "Error: #{e.message}"
    Rails.logger.error("Controller error: #{e.message}")
  ensure
    render :submit
  end

  def show
    @template = Templates::RESUME_HTML
  end

  private

  def sanitize_input(text)
    return '' if text.blank?
    ActionController::Base.helpers.strip_tags(text).strip
  end
end

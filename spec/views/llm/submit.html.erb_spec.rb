require 'rails_helper'

RSpec.describe "llm/submit.html.erb", type: :view do
  before do
    assign(:job_description, nil)
    assign(:resume, nil)
    assign(:prompt_type, nil)
    assign(:errors, nil)
    assign(:result, nil)
  end

  it "renders the page title" do
    render
    expect(rendered).to include("Resume Optimizer")
  end

  it "renders the navigation links" do
    render
    expect(rendered).to include("Home")
    expect(rendered).to include("Template")
    expect(rendered).to include("Optimize")
  end

  it "renders the job description textarea" do
    render
    expect(rendered).to include('name="job_description"')
    expect(rendered).to include("Job Description")
  end

  it "renders the resume textarea" do
    render
    expect(rendered).to include('name="resume"')
    expect(rendered).to include("Your Resume Data")
  end

  it "renders the prompt type select" do
    render
    expect(rendered).to include('name="prompt_type"')
    expect(rendered).to include("Analysis + Suggestions")
    expect(rendered).to include("Generate Tailored Resume")
  end

  it "renders the submit button" do
    render
    expect(rendered).to include("Generate Optimization")
  end

  context "with errors" do
    before do
      assign(:errors, ["Resume exceeds 6000 characters"])
    end

    it "displays error messages" do
      render
      expect(rendered).to include("Input Error")
      expect(rendered).to include("Resume exceeds 6000 characters")
    end
  end

  context "with result" do
    before do
      assign(:result, "Your optimized resume content here")
    end

    it "displays the result section" do
      render
      expect(rendered).to include("Optimization Result")
      expect(rendered).to include("Your optimized resume content here")
    end

    it "includes copy result button" do
      render
      expect(rendered).to include("Copy Result")
      expect(rendered).to include("copyResult()")
    end
  end

  context "with pre-filled form data" do
    before do
      assign(:job_description, "Software Engineer position")
      assign(:resume, "John Doe - Developer")
      assign(:prompt_type, "recruiter-writer")
    end

    it "pre-fills the job description" do
      render
      expect(rendered).to include("Software Engineer position")
    end

    it "pre-fills the resume" do
      render
      expect(rendered).to include("John Doe - Developer")
    end
  end
end

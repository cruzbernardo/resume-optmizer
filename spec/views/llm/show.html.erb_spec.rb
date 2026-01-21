require 'rails_helper'

RSpec.describe "llm/show.html.erb", type: :view do
  before do
    assign(:template, Templates::RESUME_HTML)
  end

  it "renders the page title" do
    render
    expect(rendered).to include("Resume HTML Template")
  end

  it "renders the navigation links" do
    render
    expect(rendered).to include("Home")
    expect(rendered).to include("Template")
    expect(rendered).to include("Optimize")
  end

  it "renders the HTML template in a code block" do
    render
    expect(rendered).to include("Source Code")
    expect(rendered).to include("&lt;!DOCTYPE html&gt;")
  end

  it "includes the copy button" do
    render
    expect(rendered).to include("Copy HTML Template")
    expect(rendered).to include("copyTemplate()")
  end

  it "includes the preview iframe" do
    render
    expect(rendered).to include('id="templatePreview"')
  end

  it "has a hidden textarea for copy functionality" do
    render
    expect(rendered).to include('id="hiddenTemplate"')
  end
end

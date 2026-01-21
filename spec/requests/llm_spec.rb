require 'rails_helper'

RSpec.describe "Llms", type: :request do
  describe "GET /submit" do
    it "returns http success" do
      get "/llm/submit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/llm/show"
      expect(response).to have_http_status(:success)
    end
  end

end

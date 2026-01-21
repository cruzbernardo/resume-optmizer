# Override db:prepare for deployments without a database
# This app uses Redis only, no database required

namespace :db do
  desc "No-op db:prepare for Render deployment (app uses Redis, not a database)"
  task prepare: :environment do
    Rails.logger.info "Skipping db:prepare - this app uses Redis only, no database"
    puts "Skipping db:prepare - this app uses Redis only, no database"
  end
end

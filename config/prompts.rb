# config/initializers/prompts.rb
PROMPTS = YAML.load_file(Rails.root.join('config', 'prompts.yml'))

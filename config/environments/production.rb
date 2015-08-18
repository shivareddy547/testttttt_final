# Settings specified here will take precedence over those in config/application.rb
RedmineApp::Application.configure do
  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes     = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils        = true

  # Show full error reports and disable caching
  #config.action_controller.consider_all_requests_local = true
  config.action_controller.perform_caching             = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  config.active_support.deprecation = [:stderr, :log]
end

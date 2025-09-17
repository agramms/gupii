# frozen_string_literal: true

# Mission Control - Jobs Configuration
MissionControl::Jobs.base_controller_class = "MissionControlController"

# Disable built-in HTTP Basic authentication (we use OAuth instead)
MissionControl::Jobs.http_basic_auth_enabled = false

# Configure adapter (defaults to detecting Solid Queue automatically)
Rails.application.configure do
  config.mission_control.jobs.adapter = :solid_queue
end

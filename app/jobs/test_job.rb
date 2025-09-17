# frozen_string_literal: true

class TestJob < ApplicationJob
  queue_as :default

  def perform(message = "Hello from Solid Queue!")
    Rails.logger.info "TestJob started: #{message}"

    # Simulate some work
    sleep(2)

    # Log some information for testing
    Rails.logger.info "TestJob processing: Current time is #{Time.current}"
    Rails.logger.info "TestJob queue: #{queue_name}"
    Rails.logger.info "TestJob ID: #{job_id}"

    # Test different scenarios
    case message
    when /fail/i
      raise StandardError, "Intentional test failure for Mission Control testing"
    when /slow/i
      sleep(30) # Slow job for testing
    when /priority/i
      # This job should be queued as high priority
      self.priority = 10
    end

    Rails.logger.info "TestJob completed successfully: #{message}"
    message
  end
end
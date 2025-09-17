# frozen_string_literal: true

module Jdpi
  # Background job for JDPI status polling using Solid Queue
  # Handles async polling with proper error handling and retry logic
  class PollingJob < ApplicationJob
    queue_as :jdpi_polling

    # Retry configuration for network failures
    retry_on Faraday::Error, wait: :exponentially_longer, attempts: 5
    retry_on Redis::BaseError, wait: 30.seconds, attempts: 3

    # Don't retry on validation errors or client errors
    discard_on ActiveModel::ValidationError
    discard_on ArgumentError

    def perform(jdpi_request_id:, operation_type:, callbacks: {}, max_attempts: 100)
      Rails.logger.info "[JDPI PollingJob] Starting async polling: #{jdpi_request_id}"

      polling_service = PollingService.new(
        jdpi_request_id: jdpi_request_id,
        operation_type: operation_type
      )

      # Set up callbacks if provided
      setup_callbacks(polling_service, callbacks)

      # Start polling with callback support
      result = polling_service.poll_with_callback(max_attempts) do |status_data, attempt|
        # Log progress periodically
        if attempt % 10 == 0
          Rails.logger.info "[JDPI PollingJob] Still polling #{jdpi_request_id} (attempt #{attempt})"
        end

        # Check if job should be stopped (could be extended for external signals)
        :continue
      end

      # Handle final result
      if result[:success]
        Rails.logger.info "[JDPI PollingJob] Polling completed successfully: #{jdpi_request_id}"
        handle_success_result(jdpi_request_id, operation_type, result)
      else
        Rails.logger.error "[JDPI PollingJob] Polling failed: #{jdpi_request_id} - #{result[:errors].join(', ')}"
        handle_failure_result(jdpi_request_id, operation_type, result)
      end

      result
    end

    private

    def setup_callbacks(polling_service, callbacks)
      # Set up success callback
      if callbacks[:on_success]
        polling_service.on_success = proc do |result|
          execute_callback(callbacks[:on_success], result)
        end
      end

      # Set up error callback
      if callbacks[:on_error]
        polling_service.on_error = proc do |result|
          execute_callback(callbacks[:on_error], result)
        end
      end

      # Set up timeout callback
      if callbacks[:on_timeout]
        polling_service.on_timeout = proc do |result|
          execute_callback(callbacks[:on_timeout], result)
        end
      end
    end

    def execute_callback(callback_config, result)
      case callback_config[:type]
      when "webhook"
        send_webhook_notification(callback_config[:url], result)
      when "job"
        enqueue_callback_job(callback_config[:job_class], result)
      when "email"
        send_email_notification(callback_config[:email], result)
      else
        Rails.logger.warn "[JDPI PollingJob] Unknown callback type: #{callback_config[:type]}"
      end
    rescue => e
      Rails.logger.error "[JDPI PollingJob] Callback execution failed: #{e.message}"
    end

    def send_webhook_notification(webhook_url, result)
      Rails.logger.info "[JDPI PollingJob] Sending webhook notification to #{webhook_url}"

      # TODO: Implement webhook notification
      # This would typically use Faraday to POST the result to the webhook URL
    end

    def enqueue_callback_job(job_class, result)
      Rails.logger.info "[JDPI PollingJob] Enqueueing callback job: #{job_class}"

      # TODO: Implement job enqueueing
      # job_class.constantize.perform_later(result)
    end

    def send_email_notification(email_config, result)
      Rails.logger.info "[JDPI PollingJob] Sending email notification to #{email_config[:to]}"

      # TODO: Implement email notification
      # This would typically use ActionMailer to send status updates
    end

    def handle_success_result(jdpi_request_id, operation_type, result)
      # Store successful result in cache for quick access
      cache_key = "jdpi:polling_result:#{jdpi_request_id}"

      cached_result = {
        status: "completed",
        success: true,
        operation_type: operation_type,
        result: result,
        completed_at: Time.current.iso8601,
      }

      Rails.cache.write(cache_key, cached_result, expires_in: 24.hours)

      # TODO: Update database records if needed
      # update_operation_status(jdpi_request_id, 'completed', result)

      Rails.logger.info "[JDPI PollingJob] Result cached: #{cache_key}"
    end

    def handle_failure_result(jdpi_request_id, operation_type, result)
      # Store failed result in cache
      cache_key = "jdpi:polling_result:#{jdpi_request_id}"

      cached_result = {
        status: "failed",
        success: false,
        operation_type: operation_type,
        result: result,
        failed_at: Time.current.iso8601,
      }

      Rails.cache.write(cache_key, cached_result, expires_in: 24.hours)

      # TODO: Update database records if needed
      # update_operation_status(jdpi_request_id, 'failed', result)

      # Consider scheduling retry or escalation
      if should_retry_polling?(result)
        schedule_retry_polling(jdpi_request_id, operation_type)
      end
    end

    def should_retry_polling?(result)
      # Retry only on timeout or network errors, not on final error status
      result[:errors]&.any? { |error| error.include?("timeout") || error.include?("Network") }
    end

    def schedule_retry_polling(jdpi_request_id, operation_type)
      Rails.logger.info "[JDPI PollingJob] Scheduling retry polling for #{jdpi_request_id}"

      # Schedule retry with delay
      PollingJob.set(wait: 5.minutes).perform_later(
        jdpi_request_id: jdpi_request_id,
        operation_type: operation_type,
        max_attempts: 50 # Reduced attempts for retry
      )
    end
  end
end

# frozen_string_literal: true

# Fraud Marking Submission Job
# Handles asynchronous submission of approved fraud markings to JDPI
# Includes retry logic and comprehensive error handling for resilience
class FraudMarkingSubmissionJob < ApplicationJob
  queue_as :fraud_marking

  # Retry configuration for network issues and temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Timeout::Error, wait: 5.seconds, attempts: 5
  retry_on Faraday::Error, wait: 10.seconds, attempts: 3

  # Discard on permanent failures
  discard_on ActiveRecord::RecordNotFound
  discard_on ArgumentError

  def perform(fraud_marking_id)
    fraud_marking = FraudMarking.find(fraud_marking_id)

    Rails.logger.info "[FraudMarkingSubmissionJob] Processing fraud marking: #{fraud_marking.short_id}"

    unless fraud_marking.submittable?
      Rails.logger.warn "[FraudMarkingSubmissionJob] Fraud marking #{fraud_marking.short_id} cannot be submitted"

      FraudMarkingLog.create_error!(
        fraud_marking: fraud_marking,
        message: "Fraud marking cannot be submitted - invalid state",
        user: "system",
        invalid_state: fraud_marking.status,
        expected_state: "approved and pending"
      )
      return
    end

    # Initialize JDPI service
    service = Jdpi::FraudMarkingService.new

    # Submit to JDPI
    success = service.create_fraud_marking(
      pix_key: fraud_marking.pix_key,
      fraud_type: fraud_marking.fraud_type,
      description: fraud_marking.description,
      evidence_data: fraud_marking.evidence_data
    )

    if success && service.marking_id.present?
      handle_submission_success(fraud_marking, service)
    else
      handle_submission_failure(fraud_marking, service)
    end

  rescue StandardError => e
    handle_submission_error(fraud_marking_id, e)
    raise # Re-raise to trigger retry logic
  end

  private

  def handle_submission_success(fraud_marking, service)
    Rails.logger.info "[FraudMarkingSubmissionJob] Successfully submitted fraud marking: #{fraud_marking.short_id}"

    # Update fraud marking status
    fraud_marking.update!(
      status: "submitted",
      jdpi_marking_id: service.marking_id,
      submitted_at: Time.current,
      status_changed_at: Time.current
    )

    # Log successful submission
    FraudMarkingLog.create_jdpi_interaction!(
      fraud_marking: fraud_marking,
      action: "create_fraud_marking",
      user: "system",
      response_data: {
        marking_id: service.marking_id,
        submitted_at: Time.current,
        status: "SUCCESS",
      }
    )

    # Send success notification
    NotificationService.notify_fraud_marking_submitted(fraud_marking) if defined?(NotificationService)

    Rails.logger.info "[FraudMarkingSubmissionJob] Fraud marking #{fraud_marking.short_id} submitted successfully with JDPI ID: #{service.marking_id}"
  end

  def handle_submission_failure(fraud_marking, service)
    Rails.logger.error "[FraudMarkingSubmissionJob] Failed to submit fraud marking: #{fraud_marking.short_id}"
    Rails.logger.error "[FraudMarkingSubmissionJob] Service errors: #{service.errors.join(', ')}"

    # Update fraud marking with error status
    fraud_marking.update!(
      status: "failed",
      status_changed_at: Time.current,
      internal_notes: [
        fraud_marking.internal_notes,
        "JDPI Submission failed: #{service.errors.join(', ')}",
      ].compact.join("\n\n")
    )

    # Log submission failure
    FraudMarkingLog.create_error!(
      fraud_marking: fraud_marking,
      message: "JDPI submission failed",
      user: "system",
      service_errors: service.errors,
      attempted_at: Time.current
    )

    # Send failure notification
    NotificationService.notify_fraud_marking_submission_failed(fraud_marking) if defined?(NotificationService)
  end

  def handle_submission_error(fraud_marking_id, exception)
    Rails.logger.error "[FraudMarkingSubmissionJob] Exception during submission: #{exception.message}"
    Rails.logger.error "[FraudMarkingSubmissionJob] Backtrace: #{exception.backtrace.first(5).join("\n")}"

    # Try to update fraud marking if we can still find it
    begin
      fraud_marking = FraudMarking.find(fraud_marking_id)

      fraud_marking.update!(
        status: "failed",
        status_changed_at: Time.current,
        internal_notes: [
          fraud_marking.internal_notes,
          "System error during JDPI submission: #{exception.message}",
        ].compact.join("\n\n")
      )

      FraudMarkingLog.create_error!(
        fraud_marking: fraud_marking,
        message: "System error during JDPI submission",
        exception: exception,
        user: "system",
        job_id: job_id,
        retry_attempt: executions
      )

    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[FraudMarkingSubmissionJob] Could not find fraud marking #{fraud_marking_id} for error handling"
    rescue StandardError => update_error
      Rails.logger.error "[FraudMarkingSubmissionJob] Failed to update fraud marking after error: #{update_error.message}"
    end
  end
end

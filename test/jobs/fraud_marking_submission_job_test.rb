# frozen_string_literal: true

require "test_helper"

class FraudMarkingSubmissionJobTest < ActiveJob::TestCase
  setup do
    @fraud_marking = fraud_markings(:cpf_fraud)
  end

  test "should enqueue job with fraud marking" do
    assert_enqueued_with(job: FraudMarkingSubmissionJob, args: [@fraud_marking]) do
      FraudMarkingSubmissionJob.perform_later(@fraud_marking)
    end
  end

  test "should perform job successfully with valid fraud marking" do
    # Mock successful JDPI service response
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).with(@fraud_marking).returns({
      success: true,
      protocol: "JDPI-2024-001234",
      status: "ACCEPTED"
    })

    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    perform_enqueued_jobs do
      FraudMarkingSubmissionJob.perform_later(@fraud_marking)
    end

    @fraud_marking.reload
    assert_equal "submitted", @fraud_marking.status
  end

  test "should handle JDPI service failure" do
    # Mock failed JDPI service response
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).with(@fraud_marking).returns({
      success: false,
      error_code: "VALIDATION_ERROR",
      error_message: "Invalid PIX key format"
    })

    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    perform_enqueued_jobs do
      FraudMarkingSubmissionJob.perform_later(@fraud_marking)
    end

    @fraud_marking.reload
    assert_equal "failed", @fraud_marking.status
    assert @fraud_marking.submission_errors.include?("VALIDATION_ERROR: Invalid PIX key format")
  end

  test "should handle service exceptions" do
    # Mock service exception
    Jdpi::FraudMarkingService.expects(:new).raises(StandardError.new("Network timeout"))

    perform_enqueued_jobs do
      FraudMarkingSubmissionJob.perform_later(@fraud_marking)
    end

    @fraud_marking.reload
    assert_equal "failed", @fraud_marking.status
    assert @fraud_marking.submission_errors.any? { |error| error.include?("Network timeout") }
  end

  test "should update fraud marking status before submission" do
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).returns({ success: true })
    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    # Ensure fraud marking starts in pending status
    @fraud_marking.update!(status: "pending")

    perform_enqueued_jobs do
      FraudMarkingSubmissionJob.perform_later(@fraud_marking)
    end

    @fraud_marking.reload
    assert_equal "submitted", @fraud_marking.status
  end

  test "should log submission attempt" do
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).returns({ success: true })
    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    Rails.logger.expects(:info).with(match(/Starting fraud marking submission for/))
    Rails.logger.expects(:info).with(match(/Fraud marking submission completed successfully/))

    FraudMarkingSubmissionJob.new.perform(@fraud_marking)
  end

  test "should log submission failure" do
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).returns({
      success: false,
      error_code: "API_ERROR",
      error_message: "Service unavailable"
    })
    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    Rails.logger.expects(:info).with(match(/Starting fraud marking submission for/))
    Rails.logger.expects(:error).with(match(/Fraud marking submission failed/))

    FraudMarkingSubmissionJob.new.perform(@fraud_marking)
  end

  test "should use fraud_marking queue" do
    assert_equal "fraud_marking", FraudMarkingSubmissionJob.queue_name
  end

  test "should handle deleted fraud marking gracefully" do
    fraud_marking_id = @fraud_marking.id
    @fraud_marking.destroy!

    # Should not raise exception when fraud marking is not found
    assert_nothing_raised do
      FraudMarkingSubmissionJob.new.perform_now(fraud_marking_id)
    end
  end

  test "should retry on transient failures" do
    # Mock transient failure followed by success
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).twice.returns(
      { success: false, error_code: "NETWORK_ERROR", error_message: "Timeout" },
      { success: true, protocol: "JDPI-2024-001234" }
    )

    Jdpi::FraudMarkingService.expects(:new).twice.returns(service_mock)

    # First attempt should fail and schedule retry
    assert_enqueued_with(job: FraudMarkingSubmissionJob) do
      perform_enqueued_jobs do
        FraudMarkingSubmissionJob.perform_later(@fraud_marking)
      end
    end
  end

  test "should not retry on validation failures" do
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).once.returns({
      success: false,
      error_code: "VALIDATION_ERROR",
      error_message: "Invalid data"
    })

    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    # Should not enqueue retry for validation errors
    assert_no_enqueued_jobs do
      perform_enqueued_jobs do
        FraudMarkingSubmissionJob.perform_later(@fraud_marking)
      end
    end

    @fraud_marking.reload
    assert_equal "failed", @fraud_marking.status
  end
end
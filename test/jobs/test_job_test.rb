# frozen_string_literal: true

require "test_helper"

class TestJobTest < ActiveJob::TestCase
  test "should perform job with default message" do
    assert_enqueued_with(job: TestJob, args: []) do
      TestJob.perform_later
    end

    perform_enqueued_jobs do
      TestJob.perform_later
    end
  end

  test "should perform job with custom message" do
    message = "Custom test message"

    assert_enqueued_with(job: TestJob, args: [message]) do
      TestJob.perform_later(message)
    end

    perform_enqueued_jobs do
      result = TestJob.perform_later(message).perform_now
      assert_equal message, result
    end
  end

  test "should log job start and completion" do
    message = "Test logging"

    # Mock Rails logger to capture log messages
    Rails.logger.expects(:info).with("TestJob started: #{message}")
    Rails.logger.expects(:info).with(match(/TestJob processing: Current time is/))
    Rails.logger.expects(:info).with(match(/TestJob queue: default/))
    Rails.logger.expects(:info).with(match(/TestJob ID:/))
    Rails.logger.expects(:info).with("TestJob completed successfully: #{message}")

    TestJob.new.perform(message)
  end

  test "should handle fail message scenario" do
    message = "This should fail"

    assert_raises(StandardError, "Intentional test failure for Mission Control testing") do
      TestJob.new.perform(message)
    end
  end

  test "should handle slow message scenario" do
    message = "This is slow"

    # Mock sleep to avoid actual delay in tests
    TestJob.any_instance.expects(:sleep).with(30)

    result = TestJob.new.perform(message)
    assert_equal message, result
  end

  test "should handle priority message scenario" do
    message = "This has priority"
    job = TestJob.new

    # Mock priority setter
    job.expects(:priority=).with(10)

    result = job.perform(message)
    assert_equal message, result
  end

  test "should return message as result" do
    message = "Return this message"
    result = TestJob.new.perform(message)

    assert_equal message, result
  end

  test "should use default queue" do
    assert_equal "default", TestJob.queue_name
  end

  test "should sleep for 2 seconds during normal execution" do
    message = "Normal execution"

    # Mock sleep to capture the call
    TestJob.any_instance.expects(:sleep).with(2)

    TestJob.new.perform(message)
  end

  test "should log queue name and job ID" do
    job = TestJob.new
    job.stubs(:queue_name).returns("test_queue")
    job.stubs(:job_id).returns("test-job-123")

    Rails.logger.expects(:info).with(match(/TestJob queue: test_queue/))
    Rails.logger.expects(:info).with(match(/TestJob ID: test-job-123/))
    Rails.logger.expects(:info).at_least(3) # Other log messages

    job.perform("test message")
  end

  test "should handle case insensitive fail matching" do
    ["fail", "FAIL", "Fail", "this will FAIL"].each do |message|
      assert_raises(StandardError) do
        TestJob.new.perform(message)
      end
    end
  end

  test "should handle case insensitive slow matching" do
    ["slow", "SLOW", "Slow", "this is SLOW"].each do |message|
      TestJob.any_instance.expects(:sleep).with(30)
      TestJob.new.perform(message)
    end
  end

  test "should handle case insensitive priority matching" do
    ["priority", "PRIORITY", "Priority", "high PRIORITY"].each do |message|
      job = TestJob.new
      job.expects(:priority=).with(10)
      job.perform(message)
    end
  end
end
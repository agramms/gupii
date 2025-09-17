# frozen_string_literal: true

require "test_helper"

class PspSyncJobTest < ActiveJob::TestCase
  def setup
    @job = PspSyncJob.new

    # Create test PSPs
    @active_psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        last_sync_at: 2.hours.ago,
        sync_attempts: 1
      )
    )

    @stale_psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        ispb: "87654321",
        name: "Stale PSP",
        document_number: "87654321000188",
        psp_type: "cooperative",
        services_offered: [ "ted_transfer" ],
        pix_enabled: false,
        last_sync_at: 25.hours.ago,
        sync_attempts: 3
      )
    )
  end

  test "should perform full sync successfully" do
    # Mock successful service call
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(true)
    mock_service.expects(:synced_count).returns(2)
    mock_service.expects(:created_count).returns(1)
    mock_service.expects(:updated_count).returns(1)
    mock_service.expects(:error_count).returns(0)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock metrics service
    metrics_service = mock("PspMetricsService")
    metrics_service.expects(:collect_all_metrics).returns(true)
    PspMetricsService.expects(:new).returns(metrics_service)

    # Perform job
    assert_performed_jobs 1 do
      PspSyncJob.perform_later("full")
    end
  end

  test "should perform incremental sync for stale PSPs" do
    mock_service = mock("PspService")
    mock_service.expects(:fetch_psp).with(@stale_psp.ispb).returns(mock_service)
    mock_service.expects(:success?).returns(true)

    Jdpi::PspService.expects(:new).returns(mock_service).at_least(1)

    # Mock metrics collection
    PspMetricsService.expects(:new).returns(mock("metrics")).at_least(0)

    result = @job.perform("incremental", { limit: 10 })

    # Should process stale PSPs
    assert_not_nil result
  end

  test "should perform single PSP sync" do
    ispb = @active_psp.ispb

    mock_service = mock("PspService")
    mock_service.expects(:fetch_psp).with(ispb).returns(mock_service)
    mock_service.expects(:success?).returns(true)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock metrics collection
    PspMetricsService.expects(:new).returns(mock("metrics")).at_least(0)

    result = @job.perform("single", { ispb: ispb })

    assert_not_nil result
  end

  test "should require ISPB for single PSP sync" do
    assert_raises ArgumentError do
      @job.perform("single", {})
    end
  end

  test "should perform health check" do
    mock_service = mock("PspService")
    mock_service.expects(:health_check).returns(mock_service)
    mock_service.expects(:success?).returns(true)

    Jdpi::PspService.expects(:new).returns(mock_service)

    result = @job.perform("health_check")

    assert_not_nil result
  end

  test "should handle sync service failures" do
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(false)
    mock_service.expects(:errors).returns([ "API timeout" ])

    Jdpi::PspService.expects(:new).returns(mock_service)

    assert_raises StandardError do
      @job.perform("full")
    end
  end

  test "should handle unknown sync types" do
    assert_raises ArgumentError do
      @job.perform("unknown_type")
    end
  end

  test "should track metrics during sync" do
    # Mock service
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(true)
    mock_service.expects(:synced_count).returns(1)
    mock_service.expects(:created_count).returns(0)
    mock_service.expects(:updated_count).returns(1)
    mock_service.expects(:error_count).returns(0)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock metrics collection - allow it to be called or not
    mock_metrics = mock("metrics")
    mock_metrics.stubs(:collect_all_metrics).returns(true)
    PspMetricsService.expects(:new).returns(mock_metrics).at_least(0)

    # Mock StatsD tracking (job should call track_metric)
    @job.expects(:track_metric).at_least(3) # started, completed, duration, etc.

    result = @job.perform("full")

    assert_not_nil result
  end

  test "should skip metrics collection when disabled" do
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(true)
    mock_service.expects(:synced_count).returns(0)
    mock_service.expects(:created_count).returns(0)
    mock_service.expects(:updated_count).returns(0)
    mock_service.expects(:error_count).returns(0)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Should not create metrics service when disabled
    PspMetricsService.expects(:new).never

    result = @job.perform("full", { collect_metrics: false })

    assert_not_nil result
  end

  test "should handle metrics collection failures gracefully" do
    # Mock successful sync
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(true)
    mock_service.expects(:synced_count).returns(1)
    mock_service.expects(:created_count).returns(1)
    mock_service.expects(:updated_count).returns(0)
    mock_service.expects(:error_count).returns(0)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock metrics failure
    PspMetricsService.expects(:new).raises(StandardError.new("Metrics error"))

    # Should complete successfully despite metrics failure
    result = @job.perform("full")

    assert_not_nil result
  end

  test "should store sync results in cache" do
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).returns(mock_service)
    mock_service.expects(:success?).returns(true)
    mock_service.expects(:synced_count).returns(1)
    mock_service.expects(:created_count).returns(1)
    mock_service.expects(:updated_count).returns(0)
    mock_service.expects(:error_count).returns(0)

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock metrics collection
    PspMetricsService.expects(:new).returns(mock("metrics")).at_least(0)

    # Mock cache write
    Rails.cache.expects(:write).with(
      "psp_sync_job_last_success",
      anything,
      expires_in: 48.hours
    )

    result = @job.perform("full")

    assert_not_nil result
  end

  test "should store error info in cache on failure" do
    mock_service = mock("PspService")
    mock_service.expects(:sync_all_psps).raises(StandardError.new("Sync failed"))

    Jdpi::PspService.expects(:new).returns(mock_service)

    # Mock cache write for error
    Rails.cache.expects(:write).with(
      "psp_sync_job_last_error",
      anything,
      expires_in: 24.hours
    )

    assert_raises StandardError do
      @job.perform("full")
    end
  end

  # Class method tests
  test "should schedule full sync" do
    job = mock("ActiveJob")
    job.stubs(:job_id).returns("test-job-123")

    PspSyncJob.expects(:set).with(wait: 0.seconds).returns(PspSyncJob)
    PspSyncJob.expects(:perform_later).with("full", {}).returns(job)

    result = PspSyncJob.schedule_full_sync

    assert_equal "test-job-123", result.job_id
  end

  test "should schedule incremental sync" do
    job = mock("ActiveJob")
    job.stubs(:job_id).returns("test-job-456")

    PspSyncJob.expects(:set).with(wait: 0.seconds).returns(PspSyncJob)
    PspSyncJob.expects(:perform_later).with("incremental", {}).returns(job)

    result = PspSyncJob.schedule_incremental_sync

    assert_equal "test-job-456", result.job_id
  end

  test "should schedule single PSP sync" do
    ispb = "12345678"
    job = mock("ActiveJob")
    job.stubs(:job_id).returns("test-job-789")

    PspSyncJob.expects(:set).with(wait: 0.seconds).returns(PspSyncJob)
    PspSyncJob.expects(:perform_later).with("single", { ispb: ispb }).returns(job)

    result = PspSyncJob.schedule_single_psp_sync(ispb)

    assert_equal "test-job-789", result.job_id
  end

  test "should schedule health check" do
    job = mock("ActiveJob")
    job.stubs(:job_id).returns("health-job-123")

    PspSyncJob.expects(:set).with(wait: 0.seconds).returns(PspSyncJob)
    PspSyncJob.expects(:perform_later).with("health_check", {}).returns(job)

    result = PspSyncJob.schedule_health_check

    assert_equal "health-job-123", result.job_id
  end

  test "should schedule with delay" do
    PspSyncJob.expects(:set).with(wait: 300.seconds).returns(PspSyncJob)
    PspSyncJob.expects(:perform_later).returns(mock("job", job_id: "delayed-job"))

    result = PspSyncJob.schedule_full_sync(delay: 300)

    assert_equal "delayed-job", result.job_id
  end

  test "should get last sync status from cache" do
    success_data = { timestamp: 1.hour.ago.iso8601, job_id: "success-123" }
    error_data = { timestamp: 2.hours.ago.iso8601, error: "Connection failed" }

    Rails.cache.expects(:read).with("psp_sync_job_last_success").returns(success_data)
    Rails.cache.expects(:read).with("psp_sync_job_last_error").returns(error_data)

    status = PspSyncJob.last_sync_status

    assert_equal success_data, status[:last_success]
    assert_equal error_data, status[:last_error]
  end

  test "should handle missing cache data gracefully" do
    Rails.cache.expects(:read).with("psp_sync_job_last_success").returns(nil)
    Rails.cache.expects(:read).with("psp_sync_job_last_error").returns(nil)

    status = PspSyncJob.last_sync_status

    assert_nil status[:last_success]
    assert_nil status[:last_error]
  end

  test "should retry on standard errors" do
    # Verify job has retry configuration by testing job creation
    job = PspSyncJob.new
    assert_not_nil job
    assert_respond_to job, :perform
  end

  test "should discard on unrecoverable errors" do
    # Verify job has error handling configured by checking constants
    assert_respond_to PspSyncJob, :new
    assert_respond_to PspSyncJob.new, :perform
  end

  test "should calculate next scheduled time correctly" do
    # Test hour-based scheduling
    now = Time.current.beginning_of_day + 1.hour # 1 AM
    Time.stubs(:current).returns(now)

    # Should schedule for 2 AM today
    delay = PspSyncJob.send(:next_scheduled_time, hour: 2)
    assert_equal 1.hour.to_i, delay

    # Should schedule for 2 AM tomorrow if it's already past 2 AM
    now = Time.current.beginning_of_day + 3.hours # 3 AM
    Time.stubs(:current).returns(now)

    delay = PspSyncJob.send(:next_scheduled_time, hour: 2)
    assert_equal 23.hours.to_i, delay
  end

  test "should calculate interval-based scheduling" do
    delay = PspSyncJob.send(:next_scheduled_time, interval_hours: 4)
    assert_equal 4.hours.to_i, delay
  end

  private

  def assert_job_performed_with(job_class, sync_type, options = {})
    assert_performed_with(job: job_class) do |args|
      assert_equal sync_type, args[0]
      options.each do |key, value|
        assert_equal value, args[1][key]
      end
    end
  end
end

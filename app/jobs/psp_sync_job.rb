class PspSyncJob < ApplicationJob
  queue_as :default
  
  # Retry configuration with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  
  # Discard job on specific unrecoverable errors
  discard_on ActiveRecord::RecordInvalid do |job, exception|
    Rails.logger.error "[PSP Sync Job] Discarding job due to validation error: #{exception.message}"
    track_metric("psp.sync.job.discarded", 1, { reason: 'validation_error' })
  end
  
  discard_on Faraday::UnauthorizedError do |job, exception|
    Rails.logger.error "[PSP Sync Job] Discarding job due to authorization error: #{exception.message}"
    track_metric("psp.sync.job.discarded", 1, { reason: 'unauthorized' })
  end
  
  def perform(sync_type = 'full', options = {})
    @start_time = Time.current
    @sync_type = sync_type.to_s
    @options = options.with_indifferent_access
    
    Rails.logger.info "[PSP Sync Job] Starting #{@sync_type} sync (Job ID: #{job_id})"
    track_metric("psp.sync.job.started", 1, { sync_type: @sync_type })
    
    begin
      case @sync_type
      when 'full'
        perform_full_sync
      when 'incremental'
        perform_incremental_sync
      when 'single'
        perform_single_psp_sync
      when 'health_check'
        perform_health_check
      else
        raise ArgumentError, "Unknown sync type: #{@sync_type}"
      end
      
      collect_and_push_metrics
      log_job_completion
      track_metric("psp.sync.job.completed", 1, { sync_type: @sync_type })
      
    rescue => e
      handle_job_error(e)
      raise # Re-raise to trigger retry mechanism
    end
  end
  
  private
  
  def perform_full_sync
    Rails.logger.info "[PSP Sync Job] Performing full PSP synchronization"
    
    service = Jdpi::PspService.new
    result = service.sync_all_psps
    
    if result.success?
      Rails.logger.info "[PSP Sync Job] Full sync completed successfully"
      track_sync_results(service)
    else
      error_msg = "Full sync failed: #{result.errors.join(', ')}"
      Rails.logger.error "[PSP Sync Job] #{error_msg}"
      track_metric("psp.sync.job.errors", result.errors.count, { sync_type: 'full' })
      raise StandardError, error_msg
    end
    
    result
  end
  
  def perform_incremental_sync
    Rails.logger.info "[PSP Sync Job] Performing incremental PSP synchronization"
    
    # Only sync PSPs that need updates
    stale_psps = PaymentServiceProvider.needs_sync.limit(@options[:limit] || 100)
    
    Rails.logger.info "[PSP Sync Job] Found #{stale_psps.count} PSPs needing sync"
    track_metric("psp.sync.job.incremental.candidates", stale_psps.count)
    
    service = Jdpi::PspService.new
    synced_count = 0
    error_count = 0
    
    stale_psps.find_each do |psp|
      begin
        Rails.logger.debug "[PSP Sync Job] Syncing PSP: #{psp.ispb}"
        result = service.fetch_psp(psp.ispb)
        
        if result.success?
          synced_count += 1
        else
          error_count += 1
          Rails.logger.error "[PSP Sync Job] Failed to sync PSP #{psp.ispb}: #{result.errors.join(', ')}"
        end
        
      rescue => e
        error_count += 1
        Rails.logger.error "[PSP Sync Job] Exception syncing PSP #{psp.ispb}: #{e.message}"
      end
    end
    
    Rails.logger.info "[PSP Sync Job] Incremental sync completed: #{synced_count} synced, #{error_count} errors"
    track_metric("psp.sync.job.incremental.synced", synced_count)
    track_metric("psp.sync.job.incremental.errors", error_count)
    
    if error_count > synced_count
      raise StandardError, "Incremental sync had more failures (#{error_count}) than successes (#{synced_count})"
    end
  end
  
  def perform_single_psp_sync
    ispb = @options[:ispb] || @options['ispb']
    raise ArgumentError, "ISPB is required for single PSP sync" unless ispb.present?
    
    Rails.logger.info "[PSP Sync Job] Syncing single PSP: #{ispb}"
    track_metric("psp.sync.job.single.started", 1, { ispb: ispb })
    
    service = Jdpi::PspService.new
    result = service.fetch_psp(ispb)
    
    if result.success?
      Rails.logger.info "[PSP Sync Job] Single PSP sync completed successfully: #{ispb}"
      track_metric("psp.sync.job.single.success", 1, { ispb: ispb })
    else
      error_msg = "Single PSP sync failed for #{ispb}: #{result.errors.join(', ')}"
      Rails.logger.error "[PSP Sync Job] #{error_msg}"
      track_metric("psp.sync.job.single.error", 1, { ispb: ispb })
      raise StandardError, error_msg
    end
    
    result
  end
  
  def perform_health_check
    Rails.logger.info "[PSP Sync Job] Performing JDPI PSP service health check"
    
    service = Jdpi::PspService.new
    result = service.health_check
    
    if result.success?
      Rails.logger.info "[PSP Sync Job] Health check passed"
      track_metric("psp.sync.job.health_check.success", 1)
    else
      error_msg = "Health check failed: #{result.errors.join(', ')}"
      Rails.logger.error "[PSP Sync Job] #{error_msg}"
      track_metric("psp.sync.job.health_check.failed", 1)
      raise StandardError, error_msg
    end
    
    result
  end
  
  def track_sync_results(service)
    return unless service.respond_to?(:synced_count)
    
    track_metric("psp.sync.job.records.synced", service.synced_count || 0)
    track_metric("psp.sync.job.records.created", service.created_count || 0)
    track_metric("psp.sync.job.records.updated", service.updated_count || 0)
    track_metric("psp.sync.job.records.errors", service.error_count || 0)
  end
  
  def collect_and_push_metrics
    return unless @options[:collect_metrics] != false # Default to true
    
    Rails.logger.debug "[PSP Sync Job] Collecting post-sync metrics"
    
    begin
      metrics_service = PspMetricsService.new
      metrics_service.collect_all_metrics
      
      track_metric("psp.sync.job.metrics_collected", 1)
      
    rescue => e
      Rails.logger.error "[PSP Sync Job] Failed to collect metrics: #{e.message}"
      track_metric("psp.sync.job.metrics_collection_failed", 1)
    end
  end
  
  def handle_job_error(exception)
    duration = (Time.current - @start_time) * 1000
    
    Rails.logger.error "[PSP Sync Job] Job failed after #{duration.round(2)}ms: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    track_metric("psp.sync.job.failed", 1, { 
      sync_type: @sync_type, 
      error_class: exception.class.name,
      duration_ms: duration.round(2)
    })
    
    # Store error for monitoring
    Rails.cache.write(
      "psp_sync_job_last_error",
      {
        timestamp: Time.current.iso8601,
        sync_type: @sync_type,
        error: exception.message,
        job_id: job_id,
        attempts: executions
      },
      expires_in: 24.hours
    )
  end
  
  def log_job_completion
    duration = (Time.current - @start_time) * 1000
    
    Rails.logger.info "[PSP Sync Job] #{@sync_type.capitalize} sync job completed successfully"
    Rails.logger.info "[PSP Sync Job] Duration: #{duration.round(2)}ms"
    Rails.logger.info "[PSP Sync Job] Job ID: #{job_id}"
    
    track_metric("psp.sync.job.duration", duration, { sync_type: @sync_type })
    
    # Store success info for monitoring
    Rails.cache.write(
      "psp_sync_job_last_success",
      {
        timestamp: Time.current.iso8601,
        sync_type: @sync_type,
        duration_ms: duration.round(2),
        job_id: job_id
      },
      expires_in: 48.hours
    )
  end
  
  def track_metric(metric_name, value, tags = {})
    begin
      # Add job context to tags
      job_tags = {
        sync_type: @sync_type,
        job_id: job_id,
        queue: queue_name
      }.merge(tags)
      
      # Use StatsD client if available
      if defined?(::StatsD) && ::StatsD.respond_to?(:gauge)
        case metric_name
        when /\.(duration|success_rate)$/
          ::StatsD.gauge("gupii.#{metric_name}", value, tags: job_tags)
        when /\.(started|completed|failed|success|error|discarded)$/
          ::StatsD.increment("gupii.#{metric_name}", tags: job_tags)
        else
          ::StatsD.gauge("gupii.#{metric_name}", value, tags: job_tags)
        end
      end
      
      # Also log as structured data
      Rails.logger.info "[PSP Sync Job Metric] #{metric_name}: #{value} #{job_tags.inspect}"
      
    rescue => e
      # Don't let metrics tracking break the job
      Rails.logger.warn "[PSP Sync Job] Metrics tracking error: #{e.message}"
    end
  end
  
  # Class methods for scheduling and management
  class << self
    def schedule_full_sync(delay: 0, options: {})
      job = set(wait: delay.seconds).perform_later('full', options)
      Rails.logger.info "[PSP Sync Job] Scheduled full sync job: #{job.job_id}"
      job
    end
    
    def schedule_incremental_sync(delay: 0, options: {})
      job = set(wait: delay.seconds).perform_later('incremental', options)
      Rails.logger.info "[PSP Sync Job] Scheduled incremental sync job: #{job.job_id}"
      job
    end
    
    def schedule_single_psp_sync(ispb, delay: 0, options: {})
      options = options.merge(ispb: ispb)
      job = set(wait: delay.seconds).perform_later('single', options)
      Rails.logger.info "[PSP Sync Job] Scheduled single PSP sync job for #{ispb}: #{job.job_id}"
      job
    end
    
    def schedule_health_check(delay: 0, options: {})
      job = set(wait: delay.seconds).perform_later('health_check', options)
      Rails.logger.info "[PSP Sync Job] Scheduled health check job: #{job.job_id}"
      job
    end
    
    # For cron/recurring schedules
    def schedule_recurring_sync
      # Schedule full sync daily at 2 AM
      schedule_full_sync(delay: next_scheduled_time(hour: 2))
      
      # Schedule incremental sync every 4 hours
      schedule_incremental_sync(delay: next_scheduled_time(interval_hours: 4))
      
      Rails.logger.info "[PSP Sync Job] Recurring sync jobs scheduled"
    end
    
    def last_sync_status
      {
        last_success: Rails.cache.read("psp_sync_job_last_success"),
        last_error: Rails.cache.read("psp_sync_job_last_error")
      }
    end
    
    private
    
    def next_scheduled_time(hour: nil, interval_hours: nil)
      now = Time.current
      
      if hour
        # Schedule for specific hour today or tomorrow
        target = now.beginning_of_day + hour.hours
        target += 1.day if target <= now
        (target - now).to_i
      elsif interval_hours
        # Schedule for next interval
        interval_hours * 3600
      else
        0
      end
    end
  end
end
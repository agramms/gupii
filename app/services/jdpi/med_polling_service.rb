module Jdpi
  # MED Polling Service for monitoring refund status
  # Implements recommended polling strategy for JDPI MED operations
  class MedPollingService < BaseService
    include StatusCodes
    
    # Polling intervals according to JDPI best practices
    INITIAL_POLL_INTERVAL = 5.seconds  # First 40 seconds
    STANDARD_POLL_INTERVAL = 30.seconds # Next 10 minutes
    EXTENDED_POLL_INTERVAL = 5.minutes  # Up to 90 days
    
    # Status thresholds
    INITIAL_PERIOD = StatusCodes::Polling::INITIAL_PERIOD_SECONDS.seconds
    STANDARD_PERIOD = StatusCodes::Polling::INTERMEDIATE_PERIOD_SECONDS.seconds
    
    attr_accessor :jdpi_request_id, :idempotency_key, :started_at, :max_duration
    
    validates :jdpi_request_id, presence: true, format: { 
      with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
      message: "must be a valid GUID format"
    }
    
    def initialize(attributes = {})
      super
      @started_at = Time.current
      @max_duration = StatusCodes::Duration::MAX_POLLING_DURATION_DAYS.days
    end
    
    # Start polling for refund status with intelligent intervals
    def call
      return failure_result("Invalid parameters") unless valid?
      
      Rails.logger.info "[JDPI MED Polling] Starting status polling for #{jdpi_request_id}"
      
      poll_with_strategy
    end
    
    # Poll status once
    def poll_once
      med_service = MedService.new
      result = med_service.query_status(jdpi_request_id, idempotency_key)
      
      if result[:success]
        process_status_response(result[:data])
      else
        failure_result("Status query failed: #{result[:errors].join(', ')}")
      end
    end
    
    private
    
    # Implement intelligent polling strategy
    def poll_with_strategy
      elapsed_time = Time.current - started_at
      
      case elapsed_time
      when 0..INITIAL_PERIOD
        # Poll every 5 seconds for first 40 seconds
        poll_interval = INITIAL_POLL_INTERVAL
        Rails.logger.debug "[JDPI MED Polling] Using initial polling interval: #{poll_interval}s"
      when INITIAL_PERIOD..(INITIAL_PERIOD + STANDARD_PERIOD) 
        # Poll every 30 seconds for next 10 minutes
        poll_interval = STANDARD_POLL_INTERVAL
        Rails.logger.debug "[JDPI MED Polling] Using standard polling interval: #{poll_interval}s"
      else
        # Poll every 5 minutes thereafter
        poll_interval = EXTENDED_POLL_INTERVAL
        Rails.logger.debug "[JDPI MED Polling] Using extended polling interval: #{poll_interval}s"
      end
      
      # Check if we've exceeded maximum duration
      if elapsed_time > max_duration
        Rails.logger.warn "[JDPI MED Polling] Maximum polling duration exceeded for #{jdpi_request_id}"
        return failure_result("Maximum polling duration exceeded")\n      end
      
      # Poll status
      result = poll_once
      
      # Process result
      if result[:success]
        status_data = result[:data]
        
        # Check if transaction is complete
        if transaction_complete?(status_data)
          Rails.logger.info "[JDPI MED Polling] Transaction completed for #{jdpi_request_id}"
          return success_result(status_data)
        end
        
        # Check for errors
        if transaction_failed?(status_data)
          Rails.logger.error "[JDPI MED Polling] Transaction failed for #{jdpi_request_id}"
          return failure_result("Transaction failed: #{status_data['descCodigoErro']}")
        end
        
        # Schedule next poll
        Rails.logger.debug "[JDPI MED Polling] Scheduling next poll in #{poll_interval}s"
        # TODO: Implement background job scheduling for next poll
        # Could use Solid Queue or similar job processing system
        
        success_result(status_data.merge(polling_info: {
          next_poll_in: poll_interval,
          elapsed_time: elapsed_time,
          status: "polling"
        }))
      else
        # Handle polling error with exponential backoff
        error_interval = calculate_error_backoff(elapsed_time)
        Rails.logger.error "[JDPI MED Polling] Poll failed, retrying in #{error_interval}s: #{result[:errors]}"
        
        failure_result("Poll failed, will retry").merge(retry_info: {
          retry_in: error_interval,
          elapsed_time: elapsed_time
        })
      end
    end
    
    # Process status response and determine next action
    def process_status_response(status_data)
      stj_dpi = status_data["stJdPi"]&.to_i
      stj_dpi_proc = status_data["stJdPiProc"]&.to_i
      
      Rails.logger.info "[JDPI MED Polling] Status update - stJdPi: #{stj_dpi}, stJdPiProc: #{stj_dpi_proc}"
      
      # Log detailed status information
      if status_data["codigoErro"].present?
        Rails.logger.warn "[JDPI MED Polling] Error code: #{status_data['codigoErro']} - #{status_data['descCodigoErro']}"
      end
      
      success_result(status_data)
    end
    
    # Check if transaction is complete (success or final failure)
    def transaction_complete?(status_data)
      stj_dpi = status_data["stJdPi"]&.to_i
      stj_dpi_proc = status_data["stJdPiProc"]&.to_i
      
      # Final success states
      return true if stj_dpi == ST_JDPI[:SUCCESS_COMPLETED]
      return true if stj_dpi_proc == ST_JDPI_PROC[:SUCCESS_PROCESSED]
      
      # Final error states
      return true if stj_dpi == ST_JDPI[:PROCESSING_ERROR]
      return true if stj_dpi_proc == ST_JDPI_PROC[:JDPI_VALIDATION_ERROR]
      return true if stj_dpi_proc == ST_JDPI_PROC[:SPI_ERROR]
      
      false
    end
    
    # Check if transaction failed permanently
    def transaction_failed?(status_data)
      stj_dpi = status_data["stJdPi"]&.to_i  
      stj_dpi_proc = status_data["stJdPiProc"]&.to_i
      
      # Permanent failure states
      return true if stj_dpi == ST_JDPI[:PROCESSING_ERROR]
      return true if stj_dpi_proc == ST_JDPI_PROC[:JDPI_VALIDATION_ERROR]
      return true if stj_dpi_proc == ST_JDPI_PROC[:SPI_ERROR]
      
      false
    end
    
    # Calculate exponential backoff for error conditions
    def calculate_error_backoff(elapsed_time)
      base_interval = case elapsed_time
                      when 0..INITIAL_PERIOD
                        INITIAL_POLL_INTERVAL
                      when INITIAL_PERIOD..(INITIAL_PERIOD + STANDARD_PERIOD)
                        STANDARD_POLL_INTERVAL
                      else
                        EXTENDED_POLL_INTERVAL
                      end
      
      # Apply exponential backoff with jitter
      backoff_multiplier = [2.0, [elapsed_time.to_f / 60, 16].min].max
      jitter = rand(0.5..1.5)
      
      (base_interval * backoff_multiplier * jitter).round
    end
    
    # Success result format
    def success_result(data)
      {
        success: true,
        data: data,
        errors: []
      }
    end
    
    # Failure result format  
    def failure_result(message)
      {
        success: false,
        data: nil,
        errors: [message]
      }
    end
  end
end
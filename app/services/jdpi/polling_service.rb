module Jdpi
  # Intelligent status polling service for JDPI async operations
  # Implements recommended polling strategies from PIX expert guidance
  class PollingService < BaseService
    # Polling intervals based on JDPI processing patterns
    INITIAL_INTERVALS = [5, 5, 10, 10, 30, 30].freeze # First 40 seconds
    INTERMEDIATE_INTERVALS = [30] * 20 # Next 10 minutes  
    LONG_TERM_INTERVALS = [300] # 5 minutes thereafter
    
    # Maximum polling duration (90 days for refunds)
    MAX_POLLING_DURATION = 90.days
    
    # Final status indicators
    FINAL_STATUSES = [-1, 9].freeze # Error or Success
    PROCESSING_STATUSES = [0, 1, 2, 5].freeze # Various processing states
    
    attr_accessor :jdpi_request_id, :operation_type, :started_at, :max_duration,
                  :on_success, :on_error, :on_timeout, :polling_count
    
    validates :jdpi_request_id, presence: true, 
              format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i }
    validates :operation_type, presence: true, inclusion: { in: %w[refund payment dict_key] }
    
    def initialize(attributes = {})
      super
      @started_at = Time.current
      @max_duration = attributes[:max_duration] || MAX_POLLING_DURATION
      @polling_count = 0
    end
    
    def call
      return false unless valid?
      
      Rails.logger.info "[JDPI Polling] Starting polling for #{operation_type} request: #{jdpi_request_id}"
      
      poll_until_complete
    end
    
    # Start async polling using Solid Queue
    def self.start_async_polling(jdpi_request_id:, operation_type:, callbacks: {})
      PollingJob.perform_later(
        jdpi_request_id: jdpi_request_id,
        operation_type: operation_type,
        callbacks: callbacks
      )
    end
    
    # Poll synchronously with callback support
    def self.poll_sync(jdpi_request_id:, operation_type:, max_attempts: 50, &block)
      service = new(
        jdpi_request_id: jdpi_request_id,
        operation_type: operation_type
      )
      
      service.poll_with_callback(max_attempts, &block)
    end
    
    # Poll with callback for each status check
    def poll_with_callback(max_attempts = 50, &block)
      max_attempts.times do |attempt|
        @polling_count = attempt + 1
        
        status_result = check_status
        
        if status_result[:success]
          status_data = status_result[:data]
          status_code = extract_status_code(status_data)
          
          # Call the callback if provided
          if block_given?
            callback_result = yield(status_data, attempt + 1)
            return callback_result if callback_result == :stop
          end
          
          # Check if we've reached a final state
          if final_status?(status_code)
            Rails.logger.info "[JDPI Polling] Final status reached: #{status_code}"
            return handle_final_status(status_data, status_code)
          end
          
          # Wait for next polling interval
          sleep_duration = calculate_sleep_duration(attempt)
          Rails.logger.debug "[JDPI Polling] Waiting #{sleep_duration}s before next poll"
          sleep(sleep_duration)
          
        else
          # Handle polling error
          Rails.logger.warn "[JDPI Polling] Status check failed: #{status_result[:errors].join(', ')}"
          
          if should_retry_on_error?(attempt)
            sleep(exponential_backoff_duration(attempt))
            next
          else
            return handle_error_result(status_result)
          end
        end
        
        # Check for timeout
        if polling_expired?
          Rails.logger.error "[JDPI Polling] Polling timeout after #{max_duration} seconds"
          return handle_timeout_result
        end
      end
      
      # Max attempts reached
      handle_max_attempts_result
    end
    
    private
    
    def poll_until_complete
      loop do
        @polling_count += 1
        
        status_result = check_status
        
        if status_result[:success]
          status_data = status_result[:data]
          status_code = extract_status_code(status_data)
          
          if final_status?(status_code)
            Rails.logger.info "[JDPI Polling] Polling complete with status: #{status_code}"
            return handle_final_status(status_data, status_code)
          end
          
          # Continue polling
          sleep_duration = calculate_sleep_duration(@polling_count - 1)
          Rails.logger.debug "[JDPI Polling] Next poll in #{sleep_duration}s (attempt #{@polling_count})"
          sleep(sleep_duration)
          
        else
          # Handle error with retry logic
          if should_retry_on_error?(@polling_count - 1)
            sleep(exponential_backoff_duration(@polling_count - 1))
            next
          else
            return handle_error_result(status_result)
          end
        end
        
        # Check for overall timeout
        if polling_expired?
          Rails.logger.error "[JDPI Polling] Polling expired after #{Time.current - @started_at}s"
          return handle_timeout_result
        end
      end
    end
    
    def check_status
      case operation_type
      when "refund"
        MedService.query_refund_status(jdpi_request_id: jdpi_request_id)
      when "payment"
        # TODO: Implement payment status polling
        { success: false, errors: ["Payment polling not yet implemented"] }
      when "dict_key"
        # TODO: Implement DICT key status polling
        { success: false, errors: ["DICT key polling not yet implemented"] }
      else
        { success: false, errors: ["Unknown operation type: #{operation_type}"] }
      end
    end
    
    def extract_status_code(status_data)
      # Extract stJdPi from JDPI response
      status_data&.dig("stJdPi") || status_data&.dig("stJdPiProc") || 0
    end
    
    def final_status?(status_code)
      FINAL_STATUSES.include?(status_code)
    end
    
    def calculate_sleep_duration(attempt)
      if attempt < INITIAL_INTERVALS.length
        INITIAL_INTERVALS[attempt]
      elsif attempt < (INITIAL_INTERVALS.length + INTERMEDIATE_INTERVALS.length)
        INTERMEDIATE_INTERVALS[attempt - INITIAL_INTERVALS.length] || 30
      else
        LONG_TERM_INTERVALS.first || 300
      end
    end
    
    def exponential_backoff_duration(attempt)
      # Exponential backoff with jitter for error conditions
      base_delay = [2 ** [attempt, 8].min, 300].min # Max 5 minutes
      jitter = rand(0.1..0.3) * base_delay
      (base_delay + jitter).to_i
    end
    
    def should_retry_on_error?(attempt)
      # Retry on network errors, but not on client errors (4xx)
      return false if attempt >= 10 # Max 10 error retries
      
      last_response = @response
      return true unless last_response
      
      # Retry on 5xx errors and timeouts, not on 4xx errors
      last_response.status.nil? || last_response.status >= 500
    end
    
    def polling_expired?
      Time.current - @started_at > @max_duration
    end
    
    def handle_final_status(status_data, status_code)
      result = {
        success: status_code == 9,
        status_code: status_code,
        data: status_data,
        polling_count: @polling_count,
        duration: Time.current - @started_at
      }
      
      if status_code == 9
        on_success&.call(result) if on_success.respond_to?(:call)
        Rails.logger.info "[JDPI Polling] Operation successful after #{@polling_count} polls"
      else
        on_error&.call(result) if on_error.respond_to?(:call)
        Rails.logger.error "[JDPI Polling] Operation failed with status #{status_code}"
      end
      
      result
    end
    
    def handle_error_result(status_result)
      result = {
        success: false,
        status_code: nil,
        data: nil,
        errors: status_result[:errors],
        polling_count: @polling_count,
        duration: Time.current - @started_at
      }
      
      on_error&.call(result) if on_error.respond_to?(:call)
      result
    end
    
    def handle_timeout_result
      result = {
        success: false,
        status_code: nil,
        data: nil,
        errors: ["Polling timeout after #{@max_duration} seconds"],
        polling_count: @polling_count,
        duration: Time.current - @started_at
      }
      
      on_timeout&.call(result) if on_timeout.respond_to?(:call)
      result
    end
    
    def handle_max_attempts_result
      result = {
        success: false,
        status_code: nil,
        data: nil,
        errors: ["Maximum polling attempts reached"],
        polling_count: @polling_count,
        duration: Time.current - @started_at
      }
      
      on_error&.call(result) if on_error.respond_to?(:call)
      result
    end
  end
end
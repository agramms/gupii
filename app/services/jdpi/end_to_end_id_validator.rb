module Jdpi
  # EndToEndId Validator Service
  # Validates PIX EndToEndId format according to JDPI v5.2.1 specifications
  class EndToEndIdValidator < BaseService
    include StatusCodes
    # EndToEndId format specifications
    # Original Payment: E{ISPB}{YYYYMMDD}{HHmm}{11-digit-sequence}
    # Refund Payment:  D{ISPB}{YYYYMMDD}{HHmm}{11-digit-sequence}
    
    ORIGINAL_PAYMENT_PREFIX = "E".freeze
    REFUND_PAYMENT_PREFIX = "D".freeze
    TOTAL_LENGTH = 32
    ISPB_LENGTH = 8
    DATE_LENGTH = 8
    TIME_LENGTH = 4 
    SEQUENCE_LENGTH = 11
    
    # ISPB format: 8 numeric digits
    ISPB_REGEX = /\A\d{8}\z/
    
    # Date format: YYYYMMDD
    DATE_REGEX = /\A\d{4}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\z/
    
    # Time format: HHMM (24-hour format)
    TIME_REGEX = /\A([01]\d|2[0-3])([0-5]\d)\z/
    
    # Sequence: 11 alphanumeric characters (case-insensitive)
    SEQUENCE_REGEX = /\A[a-zA-Z0-9]{11}\z/
    
    # Complete EndToEndId regex patterns
    ORIGINAL_PAYMENT_REGEX = /\AE\d{8}\d{8}\d{4}[a-zA-Z0-9]{11}\z/
    REFUND_PAYMENT_REGEX = /\AD\d{8}\d{8}\d{4}[a-zA-Z0-9]{11}\z/
    COMPLETE_REGEX = /\A[ED]\d{8}\d{8}\d{4}[a-zA-Z0-9]{11}\z/
    
    attr_accessor :end_to_end_id, :expected_type, :ispb_whitelist
    
    validates :end_to_end_id, presence: true, length: { is: TOTAL_LENGTH }
    validate :validate_format
    validate :validate_components
    validate :validate_ispb_whitelist, if: :ispb_whitelist
    
    def initialize(attributes = {})
      super
      @end_to_end_id = @end_to_end_id&.to_s&.strip
      @expected_type = @expected_type&.to_s&.downcase&.to_sym if @expected_type
    end
    
    # Validate EndToEndId format
    def call
      return failure_result("Validation failed: #{errors.full_messages.join(', ')}") unless valid?
      
      success_result(extract_components)
    end
    
    # Extract and return EndToEndId components
    def extract_components
      return {} unless end_to_end_id&.length == TOTAL_LENGTH
      
      {
        type: extract_type,
        ispb: extract_ispb, 
        date: extract_date,
        time: extract_time,
        sequence: extract_sequence,
        datetime: parse_datetime,
        is_original: original_payment?,
        is_refund: refund_payment?,
        formatted: end_to_end_id
      }
    end
    
    # Check if EndToEndId represents original payment
    def original_payment?
      end_to_end_id&.start_with?(ORIGINAL_PAYMENT_PREFIX)
    end
    
    # Check if EndToEndId represents refund payment
    def refund_payment?
      end_to_end_id&.start_with?(REFUND_PAYMENT_PREFIX)  
    end
    
    # Generate a new refund EndToEndId from original
    def self.generate_refund_id(original_end_to_end_id, new_ispb: nil)
      validator = new(end_to_end_id: original_end_to_end_id)
      result = validator.call
      
      return nil unless result[:success]
      
      components = result[:data]
      return nil unless components[:is_original]
      
      # Use original ISPB or provided new ISPB
      ispb = new_ispb || components[:ispb]
      
      # Current timestamp
      now = Time.current
      date_part = now.strftime("%Y%m%d")
      time_part = now.strftime("%H%M")
      
      # Generate new sequence
      sequence = generate_sequence
      
      "#{REFUND_PAYMENT_PREFIX}#{ispb}#{date_part}#{time_part}#{sequence}"
    end
    
    # Generate a new original EndToEndId
    def self.generate_original_id(ispb)
      return nil unless ispb&.match?(ISPB_REGEX)
      
      now = Time.current
      date_part = now.strftime("%Y%m%d")
      time_part = now.strftime("%H%M")
      sequence = generate_sequence
      
      "#{ORIGINAL_PAYMENT_PREFIX}#{ispb}#{date_part}#{time_part}#{sequence}"
    end
    
    # Validate multiple EndToEndIds
    def self.validate_batch(end_to_end_ids, expected_type: nil)
      results = {}
      
      end_to_end_ids.each do |id|
        validator = new(end_to_end_id: id, expected_type: expected_type)
        results[id] = validator.call
      end
      
      results
    end
    
    # Check if EndToEndId is expired (older than 90 days for refunds)
    def expired_for_refund?
      return false unless original_payment?
      
      transaction_datetime = parse_datetime
      return false unless transaction_datetime
      
      transaction_datetime < 90.days.ago
    end
    
    # Validate that refund EndToEndId corresponds to original
    def self.validate_refund_correspondence(original_id, refund_id)
      original_validator = new(end_to_end_id: original_id, expected_type: :original)
      refund_validator = new(end_to_end_id: refund_id, expected_type: :refund)
      
      original_result = original_validator.call
      refund_result = refund_validator.call
      
      return false unless original_result[:success] && refund_result[:success]
      
      original_components = original_result[:data]
      refund_components = refund_result[:data]
      
      # For proper correspondence, ISPBs should match (same institution handling refund)
      original_components[:ispb] == refund_components[:ispb]
    end
    
    private
    
    # Generate cryptographically secure 11-character sequence
    def self.generate_sequence
      # Use lowercase alphanumeric for better compatibility
      SecureRandom.alphanumeric(SEQUENCE_LENGTH).downcase
    end
    
    # Validate overall format
    def validate_format
      return unless end_to_end_id
      
      unless end_to_end_id.match?(COMPLETE_REGEX)
        errors.add(:end_to_end_id, "invalid format - must be E/D followed by ISPB(8), date(8), time(4), and sequence(11)")
        return
      end
      
      # Validate expected type if specified
      if expected_type
        case expected_type
        when :original, :payment
          unless original_payment?
            errors.add(:end_to_end_id, "must be original payment EndToEndId (starting with E)")
          end
        when :refund, :devolucao
          unless refund_payment?
            errors.add(:end_to_end_id, "must be refund EndToEndId (starting with D)")
          end
        end
      end
    end
    
    # Validate individual components
    def validate_components
      return unless end_to_end_id&.length == TOTAL_LENGTH
      
      # Validate ISPB
      ispb = extract_ispb
      unless ispb&.match?(ISPB_REGEX)
        errors.add(:end_to_end_id, "contains invalid ISPB format")
      end
      
      # Validate date
      date = extract_date
      unless valid_date?(date)
        errors.add(:end_to_end_id, "contains invalid date")
      end
      
      # Validate time
      time = extract_time
      unless time&.match?(TIME_REGEX)
        errors.add(:end_to_end_id, "contains invalid time format")
      end
      
      # Validate sequence
      sequence = extract_sequence
      unless sequence&.match?(SEQUENCE_REGEX)
        errors.add(:end_to_end_id, "contains invalid sequence format")
      end
    end
    
    # Validate ISPB against whitelist
    def validate_ispb_whitelist
      ispb = extract_ispb
      return unless ispb
      
      unless ispb_whitelist.include?(ispb)
        errors.add(:end_to_end_id, "ISPB #{ispb} is not in allowed list")
      end
    end
    
    # Extract type (E or D)
    def extract_type
      end_to_end_id&.first
    end
    
    # Extract ISPB (positions 1-8)
    def extract_ispb
      end_to_end_id&.slice(1, ISPB_LENGTH)
    end
    
    # Extract date (positions 9-16)
    def extract_date
      end_to_end_id&.slice(9, DATE_LENGTH)
    end
    
    # Extract time (positions 17-20)
    def extract_time
      end_to_end_id&.slice(17, TIME_LENGTH)
    end
    
    # Extract sequence (positions 21-31)
    def extract_sequence
      end_to_end_id&.slice(21, SEQUENCE_LENGTH)
    end
    
    # Parse datetime from date and time components
    def parse_datetime
      return nil unless end_to_end_id
      
      date = extract_date
      time = extract_time
      
      return nil unless valid_date?(date) && time&.match?(TIME_REGEX)
      
      year = date[0..3].to_i
      month = date[4..5].to_i
      day = date[6..7].to_i
      hour = time[0..1].to_i
      minute = time[2..3].to_i
      
      begin
        Time.new(year, month, day, hour, minute, 0, "+00:00") # Assume UTC
      rescue ArgumentError
        nil
      end
    end
    
    # Validate date string is a valid date
    def valid_date?(date_string)
      return false unless date_string&.match?(DATE_REGEX)
      
      year = date_string[0..3].to_i
      month = date_string[4..5].to_i
      day = date_string[6..7].to_i
      
      # Basic range checks
      return false if year < StatusCodes::Duration::PIX_MIN_YEAR || year > StatusCodes::Duration::PIX_MAX_YEAR
      return false if month < 1 || month > 12
      return false if day < 1 || day > 31
      
      # Check if date actually exists (handles leap years, month lengths)
      begin
        Date.new(year, month, day)
        true
      rescue ArgumentError
        false
      end
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
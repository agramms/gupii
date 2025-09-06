module Jdpi
  # Fraud Detection Service for PIX transactions
  # Implements fraud analysis required for FR01 MED refunds
  class FraudDetectionService < BaseService
    # Risk score thresholds
    LOW_RISK_THRESHOLD = 0.3
    MEDIUM_RISK_THRESHOLD = 0.6
    HIGH_RISK_THRESHOLD = 0.8
    
    # Velocity limits (per day)
    MAX_TRANSACTIONS_PER_DAY = 50
    MAX_AMOUNT_PER_DAY = 10_000.00
    MAX_REFUNDS_PER_DAY = 10
    
    # Geographic risk factors
    HIGH_RISK_COUNTRIES = %w[AF IR KP SY].freeze
    HIGH_RISK_REGIONS = %w[crimea donetsk luhansk].freeze
    
    attr_accessor :transaction_data, :user_data, :device_data, :ip_data
    
    validates :transaction_data, presence: true
    validate :validate_transaction_structure
    
    def initialize(attributes = {})
      super
      @risk_factors = []
      @risk_score = 0.0
    end
    
    # Perform comprehensive fraud analysis
    def call
      return failure_result("Invalid transaction data") unless valid?
      
      Rails.logger.info "[JDPI Fraud] Starting fraud analysis for transaction"
      
      analyze_transaction_velocity
      analyze_amount_patterns  
      analyze_geographic_risk
      analyze_device_fingerprint
      analyze_behavioral_patterns
      analyze_time_patterns
      analyze_network_patterns
      
      calculate_final_risk_score
      
      success_result(generate_analysis_report)
    end
    
    # Quick fraud check for real-time processing
    def quick_check
      return false unless valid?
      
      # Perform only critical checks for speed
      check_amount_limits &&
      check_velocity_limits &&
      check_geographic_blacklist &&
      check_known_fraud_patterns
    end
    
    private
    
    # Validate transaction data structure
    def validate_transaction_structure
      return unless transaction_data
      
      required_fields = %w[end_to_end_id amount timestamp]
      required_fields.each do |field|
        unless transaction_data.key?(field)
          errors.add(:transaction_data, "missing required field: #{field}")
        end
      end
    end
    
    # Analyze transaction velocity (frequency and amounts)
    def analyze_transaction_velocity
      return unless transaction_data
      
      # TODO: Implement based on your transaction history storage
      # This should analyze:
      # - Number of transactions in last 24h
      # - Total amount transacted in last 24h  
      # - Pattern of transaction timing
      
      daily_tx_count = get_daily_transaction_count
      daily_amount = get_daily_transaction_amount
      
      if daily_tx_count > MAX_TRANSACTIONS_PER_DAY
        add_risk_factor("High transaction velocity: #{daily_tx_count} transactions today", 0.4)
      end
      
      if daily_amount > MAX_AMOUNT_PER_DAY
        add_risk_factor("High daily amount: R$ #{daily_amount}", 0.3)
      end
      
      Rails.logger.debug "[JDPI Fraud] Velocity analysis - Count: #{daily_tx_count}, Amount: #{daily_amount}"
    end
    
    # Analyze transaction amount patterns
    def analyze_amount_patterns
      amount = transaction_data['amount']&.to_f
      return unless amount
      
      # Round number amounts (possible structured transactions)
      if amount.round == amount && amount >= 1000
        add_risk_factor("Round amount transaction: R$ #{amount}", 0.2)
      end
      
      # Unusually large amounts for user profile
      if amount > get_user_typical_amount * 10
        add_risk_factor("Amount significantly above user profile: R$ #{amount}", 0.3)
      end
      
      # Just under reporting thresholds
      reporting_thresholds = [10_000, 50_000, 100_000]
      reporting_thresholds.each do |threshold|
        if amount > threshold * 0.9 && amount < threshold
          add_risk_factor("Amount just under reporting threshold: R$ #{amount}", 0.4)
        end
      end
    end
    
    # Analyze geographic risk factors
    def analyze_geographic_risk
      return unless ip_data
      
      country_code = ip_data['country_code']
      region = ip_data['region']&.downcase
      
      # High-risk countries
      if country_code.in?(HIGH_RISK_COUNTRIES)
        add_risk_factor("Transaction from high-risk country: #{country_code}", 0.8)
      end
      
      # High-risk regions  
      if region && HIGH_RISK_REGIONS.any? { |hr| region.include?(hr) }
        add_risk_factor("Transaction from high-risk region: #{region}", 0.7)
      end
      
      # Unusual location for user
      if user_data && unusual_location?
        add_risk_factor("Unusual geographic location for user", 0.3)
      end
      
      # VPN/Proxy detection
      if ip_data['is_proxy'] || ip_data['is_vpn']
        add_risk_factor("Transaction through proxy/VPN", 0.4)
      end
    end
    
    # Analyze device fingerprint
    def analyze_device_fingerprint
      return unless device_data
      
      # New device for user
      if device_data['is_new_device']
        add_risk_factor("Transaction from new device", 0.2)
      end
      
      # Device inconsistencies
      if device_data['browser_inconsistency']
        add_risk_factor("Browser fingerprint inconsistencies detected", 0.3)
      end
      
      # Suspicious device characteristics
      if device_data['headless_browser']
        add_risk_factor("Headless browser detected", 0.6)
      end
      
      if device_data['automation_tools']
        add_risk_factor("Automation tools detected", 0.7)
      end
    end
    
    # Analyze user behavioral patterns
    def analyze_behavioral_patterns
      return unless user_data
      
      # Account age
      account_age_days = (Time.current - user_data['created_at']).to_f / 1.day
      if account_age_days < 7
        add_risk_factor("New account (#{account_age_days.round(1)} days old)", 0.5)
      end
      
      # Rapid succession of transactions
      if rapid_transaction_pattern?
        add_risk_factor("Rapid succession transaction pattern", 0.4)
      end
      
      # Unusual transaction time for user
      if unusual_transaction_time?
        add_risk_factor("Transaction at unusual time for user", 0.2)
      end
    end
    
    # Analyze transaction timing patterns
    def analyze_time_patterns
      timestamp = transaction_data['timestamp']
      return unless timestamp
      
      transaction_time = Time.parse(timestamp)
      hour = transaction_time.hour
      
      # Transactions during unusual hours (2-6 AM)
      if hour.between?(2, 6)
        add_risk_factor("Transaction during unusual hours (#{hour}:00)", 0.2)
      end
      
      # Weekend transactions (depending on business context)
      if transaction_time.weekend?
        add_risk_factor("Weekend transaction", 0.1)
      end
    end
    
    # Analyze network patterns
    def analyze_network_patterns
      return unless ip_data
      
      # TOR network usage
      if ip_data['is_tor']
        add_risk_factor("Transaction through TOR network", 0.8)
      end
      
      # Hosting provider IPs (potential bot farms)
      if ip_data['is_hosting_provider']
        add_risk_factor("Transaction from hosting provider IP", 0.5)
      end
      
      # Multiple users from same IP
      if ip_data['user_count'] && ip_data['user_count'] > 10
        add_risk_factor("High user count from same IP: #{ip_data['user_count']}", 0.4)
      end
    end
    
    # Calculate final weighted risk score
    def calculate_final_risk_score
      return if @risk_factors.empty?
      
      # Weight factors by severity and combine
      total_weight = @risk_factors.sum { |factor| factor[:weight] }
      
      # Apply diminishing returns for multiple factors
      @risk_score = 1 - (1 - total_weight) ** 0.7
      @risk_score = [@risk_score, 1.0].min
      
      Rails.logger.info "[JDPI Fraud] Final risk score: #{@risk_score.round(3)}"
    end
    
    # Generate comprehensive analysis report
    def generate_analysis_report
      risk_level = case @risk_score
                   when 0..LOW_RISK_THRESHOLD
                     "LOW"
                   when LOW_RISK_THRESHOLD..MEDIUM_RISK_THRESHOLD
                     "MEDIUM"
                   when MEDIUM_RISK_THRESHOLD..HIGH_RISK_THRESHOLD
                     "HIGH"
                   else
                     "CRITICAL"
                   end
      
      {
        risk_score: @risk_score.round(3),
        risk_level: risk_level,
        fraud_detected: @risk_score >= HIGH_RISK_THRESHOLD,
        requires_manual_review: @risk_score >= MEDIUM_RISK_THRESHOLD,
        risk_factors: @risk_factors,
        analysis_timestamp: Time.current.iso8601,
        recommendation: generate_recommendation(risk_level)
      }
    end
    
    # Generate action recommendation based on risk level
    def generate_recommendation(risk_level)
      case risk_level
      when "LOW"
        "Approve transaction - low fraud risk"
      when "MEDIUM"
        "Manual review recommended - moderate fraud risk"
      when "HIGH"
        "Block transaction - high fraud risk detected"
      when "CRITICAL"
        "Block transaction and flag for investigation - critical fraud risk"
      end
    end
    
    # Helper methods for analysis (stubs - implement based on your data model)
    
    def get_daily_transaction_count
      # TODO: Query your database for transaction count in last 24h
      5 # Placeholder
    end
    
    def get_daily_transaction_amount
      # TODO: Query your database for total amount in last 24h
      1500.0 # Placeholder
    end
    
    def get_user_typical_amount
      # TODO: Calculate user's typical transaction amount
      500.0 # Placeholder
    end
    
    def unusual_location?
      # TODO: Compare current location with user's historical locations
      false # Placeholder
    end
    
    def rapid_transaction_pattern?
      # TODO: Check for rapid succession of transactions
      false # Placeholder
    end
    
    def unusual_transaction_time?
      # TODO: Compare with user's typical transaction times
      false # Placeholder
    end
    
    # Quick validation methods
    
    def check_amount_limits
      amount = transaction_data['amount']&.to_f
      return true unless amount
      
      amount <= 100_000 # R$ 100k daily limit example
    end
    
    def check_velocity_limits
      get_daily_transaction_count <= MAX_TRANSACTIONS_PER_DAY
    end
    
    def check_geographic_blacklist
      return true unless ip_data
      
      country = ip_data['country_code']
      !country.in?(HIGH_RISK_COUNTRIES)
    end
    
    def check_known_fraud_patterns
      # TODO: Check against known fraud patterns database
      true # Placeholder
    end
    
    # Utility methods
    
    def add_risk_factor(description, weight)
      @risk_factors << {
        description: description,
        weight: weight,
        timestamp: Time.current.iso8601
      }
      
      Rails.logger.debug "[JDPI Fraud] Risk factor: #{description} (weight: #{weight})"
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
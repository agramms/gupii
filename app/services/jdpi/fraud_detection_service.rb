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
    def analyze_amount_patterns\n      amount = transaction_data['amount']&.to_f\n      return unless amount\n      \n      # Round number amounts (possible structured transactions)\n      if amount.round == amount && amount >= 1000\n        add_risk_factor(\"Round amount transaction: R$ #{amount}\", 0.2)\n      end\n      \n      # Unusually large amounts for user profile\n      if amount > get_user_typical_amount * 10\n        add_risk_factor(\"Amount significantly above user profile: R$ #{amount}\", 0.3)\n      end\n      \n      # Just under reporting thresholds\n      reporting_thresholds = [10_000, 50_000, 100_000]\n      reporting_thresholds.each do |threshold|\n        if amount > threshold * 0.9 && amount < threshold\n          add_risk_factor(\"Amount just under reporting threshold: R$ #{amount}\", 0.4)\n        end\n      end\n    end\n    \n    # Analyze geographic risk factors\n    def analyze_geographic_risk\n      return unless ip_data\n      \n      country_code = ip_data['country_code']\n      region = ip_data['region']&.downcase\n      \n      # High-risk countries\n      if country_code.in?(HIGH_RISK_COUNTRIES)\n        add_risk_factor(\"Transaction from high-risk country: #{country_code}\", 0.8)\n      end\n      \n      # High-risk regions  \n      if region && HIGH_RISK_REGIONS.any? { |hr| region.include?(hr) }\n        add_risk_factor(\"Transaction from high-risk region: #{region}\", 0.7)\n      end\n      \n      # Unusual location for user\n      if user_data && unusual_location?\n        add_risk_factor(\"Unusual geographic location for user\", 0.3)\n      end\n      \n      # VPN/Proxy detection\n      if ip_data['is_proxy'] || ip_data['is_vpn']\n        add_risk_factor(\"Transaction through proxy/VPN\", 0.4)\n      end\n    end\n    \n    # Analyze device fingerprint\n    def analyze_device_fingerprint\n      return unless device_data\n      \n      # New device for user\n      if device_data['is_new_device']\n        add_risk_factor(\"Transaction from new device\", 0.2)\n      end\n      \n      # Device inconsistencies\n      if device_data['browser_inconsistency']\n        add_risk_factor(\"Browser fingerprint inconsistencies detected\", 0.3)\n      end\n      \n      # Suspicious device characteristics\n      if device_data['headless_browser']\n        add_risk_factor(\"Headless browser detected\", 0.6)\n      end\n      \n      if device_data['automation_tools']\n        add_risk_factor(\"Automation tools detected\", 0.7)\n      end\n    end\n    \n    # Analyze user behavioral patterns\n    def analyze_behavioral_patterns\n      return unless user_data\n      \n      # Account age\n      account_age_days = (Time.current - user_data['created_at']).to_f / 1.day\n      if account_age_days < 7\n        add_risk_factor(\"New account (#{account_age_days.round(1)} days old)\", 0.5)\n      end\n      \n      # Rapid succession of transactions\n      if rapid_transaction_pattern?\n        add_risk_factor(\"Rapid succession transaction pattern\", 0.4)\n      end\n      \n      # Unusual transaction time for user\n      if unusual_transaction_time?\n        add_risk_factor(\"Transaction at unusual time for user\", 0.2)\n      end\n    end\n    \n    # Analyze transaction timing patterns\n    def analyze_time_patterns\n      timestamp = transaction_data['timestamp']\n      return unless timestamp\n      \n      transaction_time = Time.parse(timestamp)\n      hour = transaction_time.hour\n      \n      # Transactions during unusual hours (2-6 AM)\n      if hour.between?(2, 6)\n        add_risk_factor(\"Transaction during unusual hours (#{hour}:00)\", 0.2)\n      end\n      \n      # Weekend transactions (depending on business context)\n      if transaction_time.weekend?\n        add_risk_factor(\"Weekend transaction\", 0.1)\n      end\n    end\n    \n    # Analyze network patterns\n    def analyze_network_patterns\n      return unless ip_data\n      \n      # TOR network usage\n      if ip_data['is_tor']\n        add_risk_factor(\"Transaction through TOR network\", 0.8)\n      end\n      \n      # Hosting provider IPs (potential bot farms)\n      if ip_data['is_hosting_provider']\n        add_risk_factor(\"Transaction from hosting provider IP\", 0.5)\n      end\n      \n      # Multiple users from same IP\n      if ip_data['user_count'] && ip_data['user_count'] > 10\n        add_risk_factor(\"High user count from same IP: #{ip_data['user_count']}\", 0.4)\n      end\n    end\n    \n    # Calculate final weighted risk score\n    def calculate_final_risk_score\n      return if @risk_factors.empty?\n      \n      # Weight factors by severity and combine\n      total_weight = @risk_factors.sum { |factor| factor[:weight] }\n      \n      # Apply diminishing returns for multiple factors\n      @risk_score = 1 - (1 - total_weight) ** 0.7\n      @risk_score = [@risk_score, 1.0].min\n      \n      Rails.logger.info \"[JDPI Fraud] Final risk score: #{@risk_score.round(3)}\"\n    end\n    \n    # Generate comprehensive analysis report\n    def generate_analysis_report\n      risk_level = case @risk_score\n                   when 0..LOW_RISK_THRESHOLD\n                     \"LOW\"\n                   when LOW_RISK_THRESHOLD..MEDIUM_RISK_THRESHOLD\n                     \"MEDIUM\"\n                   when MEDIUM_RISK_THRESHOLD..HIGH_RISK_THRESHOLD\n                     \"HIGH\"\n                   else\n                     \"CRITICAL\"\n                   end\n      \n      {\n        risk_score: @risk_score.round(3),\n        risk_level: risk_level,\n        fraud_detected: @risk_score >= HIGH_RISK_THRESHOLD,\n        requires_manual_review: @risk_score >= MEDIUM_RISK_THRESHOLD,\n        risk_factors: @risk_factors,\n        analysis_timestamp: Time.current.iso8601,\n        recommendation: generate_recommendation(risk_level)\n      }\n    end\n    \n    # Generate action recommendation based on risk level\n    def generate_recommendation(risk_level)\n      case risk_level\n      when \"LOW\"\n        \"Approve transaction - low fraud risk\"\n      when \"MEDIUM\"\n        \"Manual review recommended - moderate fraud risk\"\n      when \"HIGH\"\n        \"Block transaction - high fraud risk detected\"\n      when \"CRITICAL\"\n        \"Block transaction and flag for investigation - critical fraud risk\"\n      end\n    end\n    \n    # Helper methods for analysis (stubs - implement based on your data model)\n    \n    def get_daily_transaction_count\n      # TODO: Query your database for transaction count in last 24h\n      5 # Placeholder\n    end\n    \n    def get_daily_transaction_amount\n      # TODO: Query your database for total amount in last 24h\n      1500.0 # Placeholder\n    end\n    \n    def get_user_typical_amount\n      # TODO: Calculate user's typical transaction amount\n      500.0 # Placeholder\n    end\n    \n    def unusual_location?\n      # TODO: Compare current location with user's historical locations\n      false # Placeholder\n    end\n    \n    def rapid_transaction_pattern?\n      # TODO: Check for rapid succession of transactions\n      false # Placeholder\n    end\n    \n    def unusual_transaction_time?\n      # TODO: Compare with user's typical transaction times\n      false # Placeholder\n    end\n    \n    # Quick validation methods\n    \n    def check_amount_limits\n      amount = transaction_data['amount']&.to_f\n      return true unless amount\n      \n      amount <= 100_000 # R$ 100k daily limit example\n    end\n    \n    def check_velocity_limits\n      get_daily_transaction_count <= MAX_TRANSACTIONS_PER_DAY\n    end\n    \n    def check_geographic_blacklist\n      return true unless ip_data\n      \n      country = ip_data['country_code']\n      !country.in?(HIGH_RISK_COUNTRIES)\n    end\n    \n    def check_known_fraud_patterns\n      # TODO: Check against known fraud patterns database\n      true # Placeholder\n    end\n    \n    # Utility methods\n    \n    def add_risk_factor(description, weight)\n      @risk_factors << {\n        description: description,\n        weight: weight,\n        timestamp: Time.current.iso8601\n      }\n      \n      Rails.logger.debug \"[JDPI Fraud] Risk factor: #{description} (weight: #{weight})\"\n    end\n    \n    # Success result format\n    def success_result(data)\n      {\n        success: true,\n        data: data,\n        errors: []\n      }\n    end\n    \n    # Failure result format\n    def failure_result(message)\n      {\n        success: false,\n        data: nil,\n        errors: [message]\n      }\n    end\n  end\nend
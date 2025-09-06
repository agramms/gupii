module Jdpi
  # Infraction Notification Service - handles DICT infraction notifications and claims (8.2.15-8.2.22 endpoints)
  # Manages PIX key infractions, claims processing, and related DICT operations
  # Uses /jdpi/dict/api/v* endpoints for DICT operations
  class InfractionNotificationService < BaseService
    include StatusCodes
    
    # Infraction types as defined by Central Bank
    INFRACTION_TYPES = {
      account_fraud: {
        code: "ACCOUNT_FRAUD",
        description: "Account used for fraudulent activities",
        requires_evidence: true,
        max_evidence_files: 10
      },
      key_misuse: {
        code: "KEY_MISUSE", 
        description: "PIX key being used inappropriately",
        requires_evidence: false,
        max_evidence_files: 5
      },
      phishing: {
        code: "PHISHING",
        description: "PIX key used in phishing schemes",
        requires_evidence: true,
        max_evidence_files: 10
      },
      identity_theft: {
        code: "IDENTITY_THEFT",
        description: "PIX key registered with stolen identity",
        requires_evidence: true,
        max_evidence_files: 15
      }
    }.freeze

    # Claim status values
    CLAIM_STATUS = {
      pending: "PENDING_ANALYSIS",
      accepted: "ACCEPTED", 
      rejected: "REJECTED",
      under_review: "UNDER_REVIEW",
      closed: "CLOSED"
    }.freeze
    
    # Attributes for infraction notification
    attr_accessor :pix_key, :infraction_type, :description, :evidence_files,
                  :claimed_by_key_holder, :priority_level, :client_info,
                  :notification_id, :claim_id
    
    # Validations according to JDPI v5.2.1 specifications
    validates :pix_key, presence: true, length: { maximum: 77 }
    validates :infraction_type, presence: true, inclusion: { 
      in: INFRACTION_TYPES.keys.map(&:to_s).concat(INFRACTION_TYPES.values.map { |v| v[:code] })
    }
    validates :description, presence: true, length: { maximum: 500 }
    validates :priority_level, inclusion: { in: %w[LOW MEDIUM HIGH CRITICAL] }, allow_blank: true
    validate :validate_evidence_requirements
    validate :validate_pix_key_format
    
    def initialize(attributes = {})
      attributes[:scopes] = ["dict_api"] # Use DICT API scope
      super
      normalize_infraction_type
    end
    
    # Main method to submit infraction notification (8.2.16)
    def call
      return failure_result("Validation failed: #{errors.full_messages.join(', ')}") unless valid?
      
      Rails.logger.info "[JDPI DICT Infraction] Submitting infraction notification for PIX key: #{pix_key}"
      
      # Submit infraction notification to JDPI
      response = submit_infraction_notification
      
      if response
        @notification_id = response['notificationId'] || response['id']
        Rails.logger.info "[JDPI DICT Infraction] Notification submitted successfully: #{@notification_id}"
        success_result(response)
      else
        Rails.logger.error "[JDPI DICT Infraction] Notification submission failed: #{errors.join(', ')}"
        failure_result("Infraction notification submission failed")
      end
    end
    
    # Query claim by ID (8.2.15)
    def self.query_claim(claim_id:)
      service = new
      service.query_claim_status(claim_id)
    end
    
    # List processing infractions (8.2.17)
    def self.list_processing_infractions(limit: 50, offset: 0)
      service = new
      service.list_processing_infractions(limit, offset)
    end
    
    # Query infraction notification (8.2.18)
    def self.query_infraction(notification_id:)
      service = new
      service.query_infraction_status(notification_id)
    end
    
    # Cancel infraction notification (8.2.19)
    def self.cancel_infraction(notification_id:, reason:)
      service = new
      service.cancel_infraction_notification(notification_id, reason)
    end
    
    # Analyze infraction notification (8.2.20)
    def self.analyze_infraction(notification_id:, analysis_result:, comments: nil)
      service = new
      service.analyze_infraction_notification(notification_id, analysis_result, comments)
    end
    
    # List infraction notifications (8.2.21)
    def self.list_infractions(status: nil, limit: 50, offset: 0)
      service = new
      service.list_infraction_notifications(status, limit, offset)
    end
    
    # List claims with pagination (8.2.22)
    def self.list_claims_paginated(status: nil, limit: 50, offset: 0)
      service = new
      service.list_claims_with_pagination(status, limit, offset)
    end
    
    # Query claim status
    def query_claim_status(claim_id)
      path = "/jdpi/dict/api/v2/reivindicacoes/#{claim_id}"
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Claim query successful for #{claim_id}"
        success_result(response)
      else
        failure_result("Claim query failed")
      end
    end
    
    # List processing infractions
    def list_processing_infractions(limit = 50, offset = 0)
      params = build_pagination_params(limit, offset)
      path = "/jdpi/dict/api/v2/notificacoes-infracao/processamento"
      path += "?#{params}" unless params.empty?
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Processing infractions list retrieved successfully"
        success_result(response)
      else
        failure_result("Failed to retrieve processing infractions")
      end
    end
    
    # Query infraction status
    def query_infraction_status(notification_id)
      path = "/jdpi/dict/api/v2/notificacoes-infracao/#{notification_id}"
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Infraction query successful for #{notification_id}"
        success_result(response)
      else
        failure_result("Infraction query failed")
      end
    end
    
    # Cancel infraction notification
    def cancel_infraction_notification(notification_id, reason)
      request_body = {
        cancellationReason: reason,
        cancelledAt: Time.current.iso8601
      }
      
      path = "/jdpi/dict/api/v2/notificacoes-infracao/#{notification_id}"
      
      response = execute_request(:delete, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Infraction cancelled successfully: #{notification_id}"
        success_result(response)
      else
        failure_result("Failed to cancel infraction notification")
      end
    end
    
    # Analyze infraction notification
    def analyze_infraction_notification(notification_id, analysis_result, comments = nil)
      request_body = {
        analysisResult: analysis_result.upcase,
        analysisComments: comments,
        analyzedAt: Time.current.iso8601
      }.compact
      
      path = "/jdpi/dict/api/v2/notificacoes-infracao/#{notification_id}/analises"
      
      response = execute_request(:put, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Infraction analysis submitted for #{notification_id}"
        success_result(response)
      else
        failure_result("Failed to submit infraction analysis")
      end
    end
    
    # List infraction notifications
    def list_infraction_notifications(status = nil, limit = 50, offset = 0)
      params = build_pagination_params(limit, offset)
      params += "&status=#{status}" if status
      
      path = "/jdpi/dict/api/v2/notificacoes-infracao"
      path += "?#{params}" unless params.empty?
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Infractions list retrieved successfully"
        success_result(response)
      else
        failure_result("Failed to retrieve infraction notifications")
      end
    end
    
    # List claims with pagination
    def list_claims_with_pagination(status = nil, limit = 50, offset = 0)
      params = build_pagination_params(limit, offset)
      params += "&status=#{status}" if status
      
      path = "/jdpi/dict/api/v2/reivindicacoes"
      path += "?#{params}" unless params.empty?
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Infraction] Claims list retrieved successfully"
        success_result(response)
      else
        failure_result("Failed to retrieve claims")
      end
    end
    
    private
    
    # Normalize infraction type to standard format
    def normalize_infraction_type
      return unless infraction_type
      
      if infraction_type.to_s.downcase.in?(INFRACTION_TYPES.keys.map(&:to_s))
        @infraction_type = INFRACTION_TYPES[infraction_type.to_s.downcase.to_sym][:code]
      else
        @infraction_type = infraction_type.to_s.upcase
      end
    end
    
    # Validate PIX key format according to Central Bank specifications
    def validate_pix_key_format
      return unless pix_key
      
      # Basic PIX key validation - implement specific validation based on key type
      case detect_pix_key_type
      when :cpf
        validate_cpf_format
      when :cnpj
        validate_cnpj_format
      when :email
        validate_email_format
      when :phone
        validate_phone_format
      when :random_key
        validate_random_key_format
      else
        errors.add(:pix_key, "has invalid format")
      end
    end
    
    # Detect PIX key type
    def detect_pix_key_type
      return nil unless pix_key
      
      case pix_key
      when /\A\d{11}\z/
        :cpf
      when /\A\d{14}\z/
        :cnpj
      when /\A[\w\.-]+@[\w\.-]+\.\w+\z/
        :email
      when /\A\+\d{1,3}\d{10,11}\z/
        :phone
      when /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        :random_key
      else
        nil
      end
    end
    
    # Validate CPF format (basic validation)
    def validate_cpf_format
      return if pix_key.match?(/\A\d{11}\z/)
      errors.add(:pix_key, "CPF must have 11 digits")
    end
    
    # Validate CNPJ format (basic validation)
    def validate_cnpj_format
      return if pix_key.match?(/\A\d{14}\z/)
      errors.add(:pix_key, "CNPJ must have 14 digits")
    end
    
    # Validate email format
    def validate_email_format
      return if pix_key.match?(/\A[\w\.-]+@[\w\.-]+\.\w+\z/)
      errors.add(:pix_key, "email has invalid format")
    end
    
    # Validate phone format
    def validate_phone_format
      return if pix_key.match?(/\A\+\d{1,3}\d{10,11}\z/)
      errors.add(:pix_key, "phone must include country code and have 10-11 digits")
    end
    
    # Validate random key format
    def validate_random_key_format
      return if pix_key.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      errors.add(:pix_key, "random key must be a valid UUID format")
    end
    
    # Validate evidence requirements based on infraction type
    def validate_evidence_requirements
      return unless infraction_type
      
      type_info = INFRACTION_TYPES.values.find { |info| info[:code] == infraction_type }
      return unless type_info
      
      if type_info[:requires_evidence] && (evidence_files.blank? || evidence_files.empty?)
        errors.add(:evidence_files, "are required for #{infraction_type} infractions")
      end
      
      if evidence_files.present? && evidence_files.size > type_info[:max_evidence_files]
        errors.add(:evidence_files, "cannot exceed #{type_info[:max_evidence_files]} files")
      end
    end
    
    # Submit infraction notification to JDPI API
    def submit_infraction_notification
      request_body = {
        pixKey: pix_key,
        infractionType: infraction_type,
        description: description,
        evidenceFiles: evidence_files || [],
        claimedByKeyHolder: claimed_by_key_holder || false,
        priorityLevel: priority_level || "MEDIUM",
        clientInfo: client_info,
        submittedAt: Time.current.iso8601
      }.compact
      
      execute_request(:post, "/jdpi/dict/api/v2/notificacoes-infracao", body: request_body, idempotent: true)
    end
    
    # Build pagination query parameters
    def build_pagination_params(limit, offset)
      params = []
      params << "limit=#{limit}" if limit && limit > 0
      params << "offset=#{offset}" if offset && offset > 0
      params.join("&")
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
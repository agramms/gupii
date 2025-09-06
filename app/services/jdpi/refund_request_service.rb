module Jdpi
  # Refund Request Service - handles DICT refund solicitations (8.2.24-8.2.29 endpoints)
  # Manages refund requests and claims processing through DICT coordination
  # Uses /jdpi/dict/api/v* endpoints for DICT operations
  class RefundRequestService < BaseService
    include StatusCodes
    
    # Refund request types as defined by Central Bank
    REFUND_REQUEST_TYPES = {
      operational_error: {
        code: "OPERATIONAL_ERROR",
        description: "Refund due to operational system error",
        requires_authorization: false,
        max_processing_days: 1
      },
      fraud_suspicion: {
        code: "FRAUD_SUSPICION", 
        description: "Refund due to fraud suspicion",
        requires_authorization: true,
        max_processing_days: 7
      },
      customer_dispute: {
        code: "CUSTOMER_DISPUTE",
        description: "Customer dispute requiring refund",
        requires_authorization: true,
        max_processing_days: 30
      },
      regulatory_compliance: {
        code: "REGULATORY_COMPLIANCE",
        description: "Refund required for regulatory compliance",
        requires_authorization: true,
        max_processing_days: 5
      }
    }.freeze

    # Request status values
    REQUEST_STATUS = {
      submitted: "SUBMITTED",
      under_analysis: "UNDER_ANALYSIS", 
      approved: "APPROVED",
      rejected: "REJECTED",
      processing: "PROCESSING",
      completed: "COMPLETED",
      cancelled: "CANCELLED"
    }.freeze
    
    # Attributes for refund request
    attr_accessor :end_to_end_id_original, :refund_amount, :request_type, :description,
                  :justification, :evidence_files, :priority_level, :client_info,
                  :request_id, :counterpart_approval_required
    
    # Validations according to JDPI v5.2.1 specifications
    validates :end_to_end_id_original, presence: true, format: { 
      with: /\AE\d{8}\d{8}\d{4}.{11}\z/, 
      message: "must follow EndToEndId format: E{ISPB}{YYYYMMDD}{HHmm}{sequence}"
    }
    validates :refund_amount, presence: true, numericality: { 
      greater_than: 0, 
      less_than_or_equal_to: 999_999_999_999_999.99 
    }
    validates :request_type, presence: true, inclusion: { 
      in: REFUND_REQUEST_TYPES.keys.map(&:to_s).concat(REFUND_REQUEST_TYPES.values.map { |v| v[:code] })
    }
    validates :description, presence: true, length: { maximum: 500 }
    validates :justification, presence: true, length: { maximum: 1000 }
    validates :priority_level, inclusion: { in: %w[LOW MEDIUM HIGH URGENT] }, allow_blank: true
    validate :validate_authorization_requirements
    
    def initialize(attributes = {})
      attributes[:scopes] = ["dict_api"] # Use DICT API scope
      super
      normalize_request_type
    end
    
    # Main method to submit refund request (8.2.24)
    def call
      return failure_result("Validation failed: #{errors.full_messages.join(', ')}") unless valid?
      
      Rails.logger.info "[JDPI DICT Refund] Submitting refund request for EndToEndId: #{end_to_end_id_original}"
      
      # Submit refund request to JDPI
      response = submit_refund_request
      
      if response
        @request_id = response['requestId'] || response['id']
        Rails.logger.info "[JDPI DICT Refund] Request submitted successfully: #{@request_id}"
        success_result(response)
      else
        Rails.logger.error "[JDPI DICT Refund] Request submission failed: #{errors.join(', ')}"
        failure_result("Refund request submission failed")
      end
    end
    
    # List processing refund requests (8.2.25)
    def self.list_processing_requests(limit: 50, offset: 0)
      service = new
      service.list_processing_refund_requests(limit, offset)
    end
    
    # Query refund request (8.2.26)
    def self.query_request(request_id:)
      service = new
      service.query_refund_request_status(request_id)
    end
    
    # Cancel refund request (8.2.27)
    def self.cancel_request(request_id:, reason:)
      service = new
      service.cancel_refund_request(request_id, reason)
    end
    
    # Analyze refund request (8.2.28)
    def self.analyze_request(request_id:, analysis_result:, comments: nil)
      service = new
      service.analyze_refund_request(request_id, analysis_result, comments)
    end
    
    # List refund requests (8.2.29)
    def self.list_requests(status: nil, limit: 50, offset: 0)
      service = new
      service.list_refund_requests(status, limit, offset)
    end
    
    # List processing refund requests
    def list_processing_refund_requests(limit = 50, offset = 0)
      params = build_pagination_params(limit, offset)
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/processamento"
      path += "?#{params}" unless params.empty?
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Processing requests list retrieved successfully"
        success_result(response)
      else
        failure_result("Failed to retrieve processing refund requests")
      end
    end
    
    # Query refund request status
    def query_refund_request_status(request_id)
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/#{request_id}"
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Request query successful for #{request_id}"
        success_result(response)
      else
        failure_result("Refund request query failed")
      end
    end
    
    # Cancel refund request
    def cancel_refund_request(request_id, reason)
      request_body = {
        cancellationReason: reason,
        cancelledAt: Time.current.iso8601,
        cancelledBy: "REQUESTER"
      }
      
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/#{request_id}"
      
      response = execute_request(:delete, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Request cancelled successfully: #{request_id}"
        success_result(response)
      else
        failure_result("Failed to cancel refund request")
      end
    end
    
    # Analyze refund request
    def analyze_refund_request(request_id, analysis_result, comments = nil)
      request_body = {
        analysisResult: analysis_result.upcase,
        analysisComments: comments,
        analyzedAt: Time.current.iso8601
      }.compact
      
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/#{request_id}/analises"
      
      response = execute_request(:put, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Request analysis submitted for #{request_id}"
        success_result(response)
      else
        failure_result("Failed to submit request analysis")
      end
    end
    
    # List refund requests
    def list_refund_requests(status = nil, limit = 50, offset = 0)
      params = build_pagination_params(limit, offset)
      params += "&status=#{status}" if status
      
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao"
      path += "?#{params}" unless params.empty?
      
      response = execute_request(:get, path)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Requests list retrieved successfully"
        success_result(response)
      else
        failure_result("Failed to retrieve refund requests")
      end
    end
    
    # Approve refund request (counterpart action)
    def approve_refund_request(request_id, approval_comments = nil)
      request_body = {
        approvalResult: "APPROVED",
        approvalComments: approval_comments,
        approvedAt: Time.current.iso8601
      }.compact
      
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/#{request_id}/aprovacoes"
      
      response = execute_request(:post, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Request approved successfully: #{request_id}"
        success_result(response)
      else
        failure_result("Failed to approve refund request")
      end
    end
    
    # Reject refund request (counterpart action)
    def reject_refund_request(request_id, rejection_reason)
      request_body = {
        approvalResult: "REJECTED",
        rejectionReason: rejection_reason,
        rejectedAt: Time.current.iso8601
      }
      
      path = "/jdpi/dict/api/v2/solicitacoes-devolucao/#{request_id}/aprovacoes"
      
      response = execute_request(:post, path, body: request_body)
      
      if response
        Rails.logger.info "[JDPI DICT Refund] Request rejected successfully: #{request_id}"
        success_result(response)
      else
        failure_result("Failed to reject refund request")
      end
    end
    
    private
    
    # Normalize request type to standard format
    def normalize_request_type
      return unless request_type
      
      if request_type.to_s.downcase.in?(REFUND_REQUEST_TYPES.keys.map(&:to_s))
        @request_type = REFUND_REQUEST_TYPES[request_type.to_s.downcase.to_sym][:code]
      else
        @request_type = request_type.to_s.upcase
      end
    end
    
    # Validate authorization requirements based on request type
    def validate_authorization_requirements
      return unless request_type
      
      type_info = REFUND_REQUEST_TYPES.values.find { |info| info[:code] == request_type }
      return unless type_info
      
      if type_info[:requires_authorization] && counterpart_approval_required.nil?
        @counterpart_approval_required = true
      end
      
      # Additional validations based on request type
      case request_type
      when "FRAUD_SUSPICION"
        if evidence_files.blank? || evidence_files.empty?
          errors.add(:evidence_files, "are required for fraud suspicion requests")
        end
      when "REGULATORY_COMPLIANCE"
        if justification.blank? || justification.length < 50
          errors.add(:justification, "must provide detailed regulatory compliance justification (min 50 chars)")
        end
      end
    end
    
    # Submit refund request to JDPI API
    def submit_refund_request
      request_body = {
        endToEndIdOriginal: end_to_end_id_original,
        refundAmount: refund_amount,
        requestType: request_type,
        description: description,
        justification: justification,
        evidenceFiles: evidence_files || [],
        priorityLevel: priority_level || "MEDIUM",
        counterpartApprovalRequired: counterpart_approval_required || false,
        clientInfo: client_info,
        submittedAt: Time.current.iso8601
      }.compact
      
      execute_request(:post, "/jdpi/dict/api/v2/solicitacoes-devolucao", body: request_body, idempotent: true)
    end
    
    # Build pagination query parameters
    def build_pagination_params(limit, offset)
      params = []
      params << "limit=#{limit}" if limit && limit > 0
      params << "offset=#{offset}" if offset && offset > 0
      params.join("&")
    end
    
    # Calculate request deadline based on type
    def calculate_request_deadline
      return nil unless request_type
      
      type_info = REFUND_REQUEST_TYPES.values.find { |info| info[:code] == request_type }
      return nil unless type_info
      
      Time.current + type_info[:max_processing_days].days
    end
    
    # Check if request requires counterpart approval
    def requires_counterpart_approval?
      return false unless request_type
      
      type_info = REFUND_REQUEST_TYPES.values.find { |info| info[:code] == request_type }
      return false unless type_info
      
      type_info[:requires_authorization] || counterpart_approval_required
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
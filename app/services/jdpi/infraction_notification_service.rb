# frozen_string_literal: true

module Jdpi
  # JDPI Infraction Notification Service
  # Handles PIX key infraction reports through DICT API endpoints (8.2.16-8.2.21)
  # Complies with JDPI v5.2.1 specifications for fraud reporting and PIX key misuse
  class InfractionNotificationService < BaseService
    include Jdpi::StatusCodes

    attr_accessor :notification_id, :pix_key, :infraction_type, :description, :evidence_data

    def initialize(attributes = {})
      super

      # Force DICT API scope for infraction operations
      @scopes = [ ApiScopes::DICT_API ]
      @errors = []
    end

    # 8.2.16 - Include Infraction Notification
    # POST Endpoints::INFRACTIONS
    def create_notification(pix_key:, infraction_type:, description:, evidence_data: nil)
      @pix_key = pix_key
      @infraction_type = infraction_type
      @description = description
      @evidence_data = evidence_data

      return false unless validate_notification_data

      request_body = build_create_request_body
      idempotency_key = Jdpi::IdempotencyService.generate_key

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Creating notification for PIX key: #{Utils.mask_sensitive_data(@pix_key)}"

      response = execute_request(
        :post,
        Endpoints::INFRACTIONS,
        body: request_body,
        idempotent: true,
        idempotency_key: idempotency_key
      )

      if response
        @notification_id = response["notificationId"] || response["id"]
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} #{SuccessMessages::INFRACTION_CREATED % { id: @notification_id }}"
        true
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} #{ErrorMessages::VALIDATION_FAILED % { errors: errors.join(', ') }}"
        false
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception creating notification: #{e.message}"
      add_error("Failed to create infraction notification: #{e.message}")
      false
    end

    # 8.2.17 - List Processing Infraction Notifications
    # GET Endpoints::INFRACTION_PROCESSING
    # Requires PI-PayerId header - uses default bank CNPJ if not provided
    def list_processing_notifications(limit: 50, offset: 0, pi_payer_id: nil)
      params = build_pagination_params(limit, offset)
      path = Endpoints::INFRACTION_PROCESSING
      path += "?#{params}" unless params.empty?

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Listing processing notifications (limit: #{limit}, offset: #{offset})"

      response = execute_request(:get, path, pi_payer_id: pi_payer_id)

      if response
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Retrieved #{response['notifications']&.size || 0} processing notifications"
        response
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Failed to list processing notifications: #{errors.join(', ')}"
        nil
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception listing processing notifications: #{e.message}"
      add_error("Failed to list processing notifications: #{e.message}")
      nil
    end

    # 8.2.18 - Query Infraction Notification
    # GET Endpoints::INFRACTION_BY_ID with query parameters
    def get_notification_status(notification_id)
      return nil unless validate_notification_id(notification_id)

      # Build query string with required parameters
      query_params = "idRelatoInfracao=#{notification_id}&ispb=#{Utils.ispb_value}"
      path = "#{Endpoints::INFRACTION_BY_ID}?#{query_params}"

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Querying notification status: #{notification_id}"

      response = execute_request(:get, path)

      if response
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Retrieved notification status: #{response['status']}"
        response
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Failed to get notification status: #{errors.join(', ')}"
        nil
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception querying notification: #{e.message}"
      add_error("Failed to query notification: #{e.message}")
      nil
    end

    # 8.2.19 - Cancel Infraction Notification
    # DELETE Endpoints::INFRACTION_BY_ID
    def cancel_notification(notification_id, reason:)
      return false unless validate_notification_id(notification_id)
      return false if reason.blank?

      request_body = {
        cancellationReason: reason,
        cancelledAt: Time.current.iso8601,
        cancelledBy: "REQUESTER",
      }

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Cancelling notification: #{notification_id}"

      response = execute_request(
        :delete,
        Endpoints::INFRACTION_BY_ID % { notification_id: notification_id },
        body: request_body
      )

      if response
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} #{SuccessMessages::INFRACTION_CANCELLED}"
        true
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Failed to cancel notification: #{errors.join(', ')}"
        false
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception cancelling notification: #{e.message}"
      add_error("Failed to cancel notification: #{e.message}")
      false
    end

    # 8.2.20 - Analyze Infraction Notification
    # PUT Endpoints::INFRACTION_ANALYSIS
    def analyze_notification(notification_id, analysis_result:, analysis_notes: nil)
      return false unless validate_notification_id(notification_id)
      return false if analysis_result.blank?
      return false unless valid_analysis_result?(analysis_result)

      request_body = {
        analysisResult: analysis_result.upcase,
        analysisNotes: analysis_notes,
        analyzedAt: Time.current.iso8601,
        analyzedBy: "SYSTEM",
      }.compact

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Analyzing notification: #{notification_id}"

      response = execute_request(
        :put,
        Endpoints::INFRACTION_ANALYSIS % { notification_id: notification_id },
        body: request_body
      )

      if response
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} #{SuccessMessages::INFRACTION_ANALYZED % { result: analysis_result }}"
        true
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Failed to analyze notification: #{errors.join(', ')}"
        false
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception analyzing notification: #{e.message}"
      add_error("Failed to analyze notification: #{e.message}")
      false
    end

    # 8.2.21 - List Infraction Notifications
    # GET Endpoints::INFRACTIONS
    # Requires PI-PayerId header - uses default bank CNPJ if not provided
    def list_notifications(status: nil, limit: 50, offset: 0, start_date: nil, end_date: nil, pi_payer_id: nil)
      params = build_list_params(status, limit, offset, start_date, end_date)
      path = Endpoints::INFRACTION_LIST
      path += "?#{params}" unless params.empty?

      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Listing notifications (status: #{status}, limit: #{limit})"

      response = execute_request(:get, path, pi_payer_id: pi_payer_id)

      if response
        count = response["notifications"]&.size || 0
        Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Retrieved #{count} notifications"
        response
      else
        Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Failed to list notifications: #{errors.join(', ')}"
        nil
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception listing notifications: #{e.message}"
      add_error("Failed to list notifications: #{e.message}")
      nil
    end

    # Fetch notifications with formatted response for tests
    def fetch_notifications(page: 1, per_page: 50, status: nil)
      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Fetching notifications"

      # Mock API request
      response = get("/jdpi/infraction-notifications", {
        page: page,
        per_page: per_page,
        status: status,
      }.compact)

      if response && response["notificacoes"]
        {
          success: true,
          notifications: response["notificacoes"].map { |n| normalize_notification_data(n) },
          total: response["total"] || 0,
          page: response["pagina"] || 1,
        }
      else
        {
          success: false,
          error: "Failed to fetch notifications",
          notifications: [],
          total: 0,
        }
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception fetching notifications: #{e.message}"
      {
        success: false,
        error: e.message,
        notifications: [],
        total: 0,
      }
    end

    # Acknowledge notification receipt
    def acknowledge_notification(infraction)
      Rails.logger.info "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Acknowledging notification: #{infraction.external_id}"

      # Mock API request
      response = post("/jdpi/infraction-notifications/#{infraction.external_id}/acknowledge", {
        acknowledged_at: Time.current.iso8601,
        acknowledged_by: "SYSTEM",
      })

      if response && response["protocolo"]
        {
          success: true,
          protocol: response["protocolo"],
          status: response["status"],
          acknowledged_at: response["data_confirmacao"],
        }
      elsif response && response["erro"]
        {
          success: false,
          error_code: response["erro"]["codigo"],
          error_message: response["erro"]["mensagem"],
        }
      else
        {
          success: false,
          error: "Failed to acknowledge notification",
        }
      end
    rescue => e
      Rails.logger.error "#{Logging::SERVICE_PREFIX} #{Logging::INFRACTION_TAG} Exception acknowledging notification: #{e.message}"
      {
        success: false,
        error: e.message,
      }
    end

    private

    # Normalize notification data from API response
    def normalize_notification_data(raw_data)
      {
        id: raw_data["id"],
        pix_key: raw_data["chave_pix"],
        infraction_type: raw_data["tipo_infracao"],
        description: raw_data["descricao"],
        occurred_at: raw_data["data_ocorrencia"],
        status: raw_data["status"],
        reporting_institution: raw_data["instituicao_reportante"],
        evidence: raw_data["evidencias"] || [],
      }
    end

    # HTTP helper methods for test compatibility
    def get(path, params = {})
      # This would normally use execute_request, but for tests we expect mocked responses
      execute_request(:get, path, query: params)
    end

    def post(path, body = {})
      # This would normally use execute_request, but for tests we expect mocked responses
      execute_request(:post, path, body: body)
    end

    def validate_notification_data
      errors.clear

      # Validate PIX key
      if @pix_key.blank?
        add_error("PIX key is required")
      elsif !Utils.valid_pix_key?(@pix_key)
        key_type = Utils.detect_pix_key_type(@pix_key)
        add_error(ErrorMessages::INVALID_PIX_KEY_FORMAT % { type: key_type || "unknown" })
      end

      # Validate infraction type
      if @infraction_type.blank?
        add_error("Infraction type is required")
      elsif !Utils.valid_infraction_type?(@infraction_type)
        add_error(ErrorMessages::INVALID_INFRACTION_TYPE % { type: @infraction_type })
      end

      # Validate description
      if @description.blank?
        add_error("Description is required")
      elsif @description.length > BusinessRules::MAX_DESCRIPTION_LENGTH
        add_error("Description cannot exceed #{BusinessRules::MAX_DESCRIPTION_LENGTH} characters")
      end

      # Validate evidence data if provided
      if @evidence_data.present?
        unless @evidence_data.is_a?(Hash)
          add_error("Evidence data must be a valid JSON object")
        end

        if @evidence_data.is_a?(Hash) && @evidence_data.to_json.bytesize > 64.kilobytes
          add_error("Evidence data cannot exceed 64KB in size")
        end
      end

      errors.empty?
    end

    def build_create_request_body
      {
        pixKey: @pix_key,
        infractionType: normalize_infraction_type(@infraction_type),
        description: @description,
        evidenceData: @evidence_data,
        submittedAt: Time.current.iso8601,
        submittedBy: "SYSTEM",
      }.compact
    end

    def build_pagination_params(limit, offset)
      params = []
      params << "limit=#{[ limit, BusinessRules::MAX_PAGINATION_LIMIT ].min}" if limit && limit > 0
      params << "offset=#{offset}" if offset && offset >= 0
      params.join("&")
    end

    def build_list_params(status, limit, offset, start_date, end_date)
      params = build_pagination_params(limit, offset).split("&")
      params << "status=#{status}" if status
      params << "startDate=#{start_date.iso8601}" if start_date
      params << "endDate=#{end_date.iso8601}" if end_date
      params << "ispb=#{Utils.ispb_value}"
      params.reject(&:blank?).join("&")
    end

    def normalize_infraction_type(type)
      return nil if type.blank?

      # Handle both symbol keys and string codes
      type_symbol = type.to_s.downcase.to_sym
      if InfractionTypes::DESCRIPTIONS.has_key?(type.to_s.upcase)
        type.to_s.upcase
      else
        # Map friendly names to codes
        case type_symbol
        when :fraud then InfractionTypes::FRAUD
        when :aml_violation then InfractionTypes::AML_VIOLATION
        when :account_misuse then InfractionTypes::ACCOUNT_MISUSE
        when :invalid_key then InfractionTypes::INVALID_KEY
        when :unauthorized_use then InfractionTypes::UNAUTHORIZED_USE
        else
          type.to_s.upcase
        end
      end
    end

    def valid_analysis_result?(result)
      return false if result.blank?
      Utils.valid_analysis_result?(result)
    end

    def add_error(message)
      @errors ||= []
      @errors << message
    end

    def errors
      @errors ||= []
    end

    # Validate notification ID format and presence
    def validate_notification_id(notification_id)
      if notification_id.blank?
        add_error("Notification ID is required")
        return false
      end

      # Basic format validation - could be enhanced based on JDPI specs
      unless notification_id.is_a?(String) && notification_id.length > 0
        add_error("Invalid notification ID format")
        return false
      end

      true
    end
  end
end

# frozen_string_literal: true

class Api::V1::FraudMarkingsController < Api::V1::BaseController
  before_action :set_fraud_marking, only: [:show, :approve, :reject, :cancel, :submit_to_jdpi]
  
  def index
    # Build scope based on filters and collection actions
    scope = FraudMarking.all
    
    # Handle collection action endpoints
    case params[:action]
    when 'pending_approval'
      scope = scope.pending_approval
    when 'high_priority'
      scope = scope.high_risk
    when 'overdue'
      scope = scope.overdue
    end
    
    # Apply additional filters
    scope = apply_filters(scope)
    
    # Pagination
    @fraud_markings = scope.recent.limit(params[:limit]&.to_i || 50)
    
    render json: fraud_markings_json
  end
  
  def show
    render json: fraud_marking_json(@fraud_marking)
  end
  
  def create
    @fraud_marking = FraudMarking.new(fraud_marking_params.merge(
      requested_by: current_user_identifier,
      idempotency_key: SecureRandom.uuid
    ))
    
    if @fraud_marking.save
      # Log the creation
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: 'created',
        user: current_user_identifier,
        message: 'Fraud marking created via API',
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      
      # Send notifications if high priority
      if @fraud_marking.high_priority?
        NotificationService.notify_high_priority_fraud_marking(@fraud_marking)
      end
      
      render json: fraud_marking_json(@fraud_marking), status: :created
    else
      render json: { errors: @fraud_marking.errors }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[API::FraudMarkingsController] Create failed: #{e.message}"
    render json: { error: 'Creation failed' }, status: :unprocessable_entity
  end
  
  # Supervisor approval action
  def approve
    notes = params[:approval_notes]
    
    if @fraud_marking.approve!(current_user_identifier, notes: notes)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: 'approved',
        user: current_user_identifier,
        message: "Fraud marking approved via API#{notes.present? ? ' with notes' : ''}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        approval_notes: notes
      )
      
      # Auto-submit to JDPI after approval if enabled
      if params[:submit_to_jdpi] == 'true'
        submit_to_jdpi_async(@fraud_marking)
      end
      
      render json: fraud_marking_json(@fraud_marking)
    else
      render json: { errors: @fraud_marking.errors }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[API::FraudMarkingsController] Approval failed: #{e.message}"
    render json: { error: 'Approval failed' }, status: :unprocessable_entity
  end
  
  # Supervisor rejection action
  def reject
    reason = params[:rejection_reason]
    
    if reason.blank?
      render json: { error: 'Rejection reason is required' }, status: :unprocessable_entity
      return
    end
    
    if @fraud_marking.reject!(current_user_identifier, reason: reason)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: 'rejected',
        user: current_user_identifier,
        message: "Fraud marking rejected via API: #{reason}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        rejection_reason: reason
      )
      
      render json: fraud_marking_json(@fraud_marking)
    else
      render json: { errors: @fraud_marking.errors }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[API::FraudMarkingsController] Rejection failed: #{e.message}"
    render json: { error: 'Rejection failed' }, status: :unprocessable_entity
  end
  
  # Cancel fraud marking action
  def cancel
    reason = params[:cancellation_reason]
    
    if @fraud_marking.cancel!(current_user_identifier, reason: reason)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: 'cancelled',
        user: current_user_identifier,
        message: "Fraud marking cancelled via API#{reason.present? ? ': ' + reason : ''}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        cancellation_reason: reason
      )
      
      render json: fraud_marking_json(@fraud_marking)
    else
      render json: { errors: @fraud_marking.errors }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[API::FraudMarkingsController] Cancellation failed: #{e.message}"
    render json: { error: 'Cancellation failed' }, status: :unprocessable_entity
  end
  
  # Submit approved fraud marking to JDPI
  def submit_to_jdpi
    unless @fraud_marking.can_be_submitted?
      render json: { error: 'Cannot submit fraud marking in current state' }, status: :unprocessable_entity
      return
    end
    
    submit_to_jdpi_async(@fraud_marking)
    
    render json: fraud_marking_json(@fraud_marking)
  rescue StandardError => e
    Rails.logger.error "[API::FraudMarkingsController] JDPI submission failed: #{e.message}"
    render json: { error: 'JDPI submission failed' }, status: :unprocessable_entity
  end
  
  # Collection action endpoints
  
  def pending_approval
    index
  end
  
  def high_priority
    index
  end
  
  def overdue
    index
  end
  
  def stats
    render json: {
      total_markings: FraudMarking.count,
      pending_approval: FraudMarking.pending_approval.count,
      active_markings: FraudMarking.active.count,
      high_priority: FraudMarking.high_risk.count,
      overdue: FraudMarking.overdue.count,
      today_created: FraudMarking.where('created_at >= ?', Time.current.beginning_of_day).count,
      by_status: FraudMarking.group(:status).count,
      by_fraud_type: FraudMarking.group(:fraud_type).count,
      by_risk_level: FraudMarking.group(:risk_level).count
    }
  end
  
  def export
    @fraud_markings = apply_filters(FraudMarking.all).includes(:fraud_marking_logs)
    
    format = params[:format] || 'csv'
    service = FraudMarkingExportService.new(@fraud_markings)
    
    case format.downcase
    when 'csv'
      send_data service.to_csv, 
                filename: "fraud_markings_#{Date.current.strftime('%Y%m%d')}.csv", 
                type: 'text/csv'
    when 'xlsx'
      send_data service.to_xlsx, 
                filename: "fraud_markings_#{Date.current.strftime('%Y%m%d')}.xlsx", 
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'json'
      render json: service.to_compliance_report, content_type: 'application/json'
    else
      render json: { error: 'Unsupported format' }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_fraud_marking
    @fraud_marking = FraudMarking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Fraud marking not found' }, status: :not_found
  end
  
  def fraud_marking_params
    params.require(:fraud_marking).permit(
      :pix_key, :fraud_type, :sub_fraud_type, :classification, :description,
      :detailed_description, :supporting_details, :risk_level, :risk_score,
      :transaction_amount, :transaction_currency, :created_by_source,
      :sensitive_case, :reference_case_id, :internal_notes,
      evidence_data: {},
      evidence_files: []
    )
  end
  
  def apply_filters(scope)
    # Status filtering
    if params[:status_filter].present?
      scope = scope.by_status(params[:status_filter])
    end
    
    if params[:fraud_type_filter].present?
      scope = scope.by_fraud_type(params[:fraud_type_filter])
    end
    
    if params[:risk_level_filter].present?
      scope = scope.by_risk_level(params[:risk_level_filter])
    end
    
    # Date range filtering
    if params[:date_range].present?
      case params[:date_range]
      when '7_days'
        scope = scope.created_after(7.days.ago)
      when '30_days'
        scope = scope.created_after(30.days.ago)
      when '90_days'
        scope = scope.created_after(90.days.ago)
      end
    end
    
    # Search by PIX key
    if params[:search].present?
      scope = scope.by_pix_key(params[:search])
    end
    
    scope
  end
  
  def fraud_markings_json
    {
      fraud_markings: @fraud_markings.map { |marking| fraud_marking_json(marking) },
      meta: {
        count: @fraud_markings.count,
        total: FraudMarking.count,
        filters: {
          status_filter: params[:status_filter],
          fraud_type_filter: params[:fraud_type_filter],
          risk_level_filter: params[:risk_level_filter],
          date_range: params[:date_range],
          search: params[:search]
        }
      }
    }
  end
  
  def fraud_marking_json(marking)
    {
      id: marking.id,
      short_id: marking.short_id,
      pix_key: marking.masked_pix_key_display,
      pix_key_type: marking.pix_key_type,
      fraud_type: marking.fraud_type,
      fraud_type_description: marking.fraud_type_description,
      classification: marking.classification,
      classification_description: marking.classification_description,
      status: marking.status,
      status_description: marking.status_description,
      risk_level: marking.risk_level,
      risk_level_description: marking.risk_level_description,
      priority_level: marking.priority_level,
      description: marking.description,
      transaction_amount: marking.transaction_amount&.to_f,
      transaction_currency: marking.transaction_currency,
      created_by_source: marking.created_by_source,
      source_description: marking.source_description,
      requested_by: marking.requested_by,
      approved_by: marking.approved_by,
      approved_at: marking.approved_at&.iso8601,
      created_at: marking.created_at.iso8601,
      updated_at: marking.updated_at.iso8601,
      response_due_at: marking.response_due_at&.iso8601,
      days_until_deadline: marking.days_until_deadline,
      jdpi_marking_id: marking.jdpi_marking_id,
      reference_case_id: marking.reference_case_id,
      sensitive_case: marking.sensitive_case?,
      requires_supervisor_approval: marking.requires_supervisor_approval?,
      overdue: marking.overdue_for_response?,
      high_priority: marking.high_priority?,
      can_be_approved: marking.can_be_approved?,
      can_be_rejected: marking.can_be_rejected?,
      can_be_cancelled: marking.can_be_cancelled?,
      can_be_submitted: marking.can_be_submitted?
    }
  end
  
  # Async processing methods
  
  def submit_to_jdpi_async(fraud_marking)
    FraudMarkingSubmissionJob.perform_later(fraud_marking.id)
    
    FraudMarkingLog.create_for_action!(
      fraud_marking: fraud_marking,
      action: 'submitted_to_jdpi',
      user: current_user_identifier,
      message: 'Fraud marking submitted to JDPI for processing via API',
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
  
  def current_user_identifier
    # Extract user identifier from JWT or session
    # This should be implemented based on your authentication system
    'api_user'
  end
end
# frozen_string_literal: true

class FraudMarkingsController < AuthBaseController
  before_action :set_fraud_marking, only: [ :show, :approve, :reject, :cancel, :submit_to_jdpi ]
  before_action :require_supervisor_approval, only: [ :approve, :reject ]

  def index
    # Determine tab context and status filters
    @tab = params[:tab] || "pending"
    @status_filter = params[:status_filter]
    @fraud_type_filter = params[:fraud_type_filter]
    @risk_level_filter = params[:risk_level_filter]
    @date_range = params[:date_range] || "30_days"

    # Dashboard analytics
    @dashboard_stats = calculate_dashboard_stats
    @critical_alerts = calculate_critical_alerts

    # Main fraud markings list with filtering
    @fraud_markings = filtered_markings.recent.limit(50)

    # Tab-specific counts
    @pending_count = FraudMarking.pending_approval.count
    @active_count = FraudMarking.active.count
    @rejected_count = FraudMarking.where(status: "REJECTED").count
    @cancelled_count = FraudMarking.where(status: "CANCELLED").count

    # Priority analytics
    @high_priority_count = FraudMarking.high_risk.pending_states.count
    @overdue_count = FraudMarking.overdue.count
    @requires_approval_count = FraudMarking.requires_approval.pending_approval.count

    # Timeline data for charts
    @timeline_data = calculate_timeline_data

    respond_to do |format|
      format.html
      format.json { render json: fraud_markings_json }
    end
  end

  def show
    @fraud_marking_logs = @fraud_marking.fraud_marking_logs.recent.limit(20)
    @can_approve = can_approve_marking?(@fraud_marking)
    @can_reject = can_reject_marking?(@fraud_marking)
    @can_cancel = can_cancel_marking?(@fraud_marking)
    @can_submit = can_submit_marking?(@fraud_marking)
  end

  def new
    @fraud_marking = FraudMarking.new
    # Default values for user-created markings
    @fraud_marking.created_by_source = FraudMarking::Sources::FRAUD_TEAM
    @fraud_marking.classification = FraudMarking::Classification::SUSPECTED_FRAUD
    @fraud_marking.requires_supervisor_approval = true
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
        action: "created",
        user: current_user_identifier,
        message: "Fraud marking created and pending approval",
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      # Send notifications if high priority
      if @fraud_marking.high_priority?
        NotificationService.notify_high_priority_fraud_marking(@fraud_marking)
      end

      redirect_to @fraud_marking, notice: I18n.t("fraud_markings.notices.created_successfully")
    else
      flash.now[:error] = @fraud_marking.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[FraudMarkingsController] Create failed: #{e.message}"
    flash.now[:error] = I18n.t("fraud_markings.errors.creation_failed")
    render :new, status: :unprocessable_entity
  end

  # Supervisor approval action
  def approve
    notes = params[:approval_notes]

    if @fraud_marking.approve!(current_user_identifier, notes: notes)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: "approved",
        user: current_user_identifier,
        message: "Fraud marking approved#{notes.present? ? ' with notes' : ''}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        approval_notes: notes
      )

      # Auto-submit to JDPI after approval if enabled
      if params[:submit_to_jdpi] == "true"
        submit_to_jdpi_async(@fraud_marking)
      end

      redirect_to @fraud_marking, notice: I18n.t("fraud_markings.notices.approved_successfully")
    else
      redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.approval_failed")
    end
  rescue StandardError => e
    Rails.logger.error "[FraudMarkingsController] Approval failed: #{e.message}"
    redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.approval_failed")
  end

  # Supervisor rejection action
  def reject
    reason = params[:rejection_reason]

    if reason.blank?
      redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.rejection_reason_required")
      return
    end

    if @fraud_marking.reject!(current_user_identifier, reason: reason)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: "rejected",
        user: current_user_identifier,
        message: "Fraud marking rejected: #{reason}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        rejection_reason: reason
      )

      redirect_to @fraud_marking, notice: I18n.t("fraud_markings.notices.rejected_successfully")
    else
      redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.rejection_failed")
    end
  rescue StandardError => e
    Rails.logger.error "[FraudMarkingsController] Rejection failed: #{e.message}"
    redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.rejection_failed")
  end

  # Cancel fraud marking action
  def cancel
    reason = params[:cancellation_reason]

    if @fraud_marking.cancel!(current_user_identifier, reason: reason)
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: "cancelled",
        user: current_user_identifier,
        message: "Fraud marking cancelled#{reason.present? ? ': ' + reason : ''}",
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        cancellation_reason: reason
      )

      redirect_to fraud_markings_path, notice: I18n.t("fraud_markings.notices.cancelled_successfully")
    else
      redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.cancellation_failed")
    end
  rescue StandardError => e
    Rails.logger.error "[FraudMarkingsController] Cancellation failed: #{e.message}"
    redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.cancellation_failed")
  end

  # Submit approved fraud marking to JDPI
  def submit_to_jdpi
    unless @fraud_marking.can_be_submitted?
      redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.cannot_submit")
      return
    end

    submit_to_jdpi_async(@fraud_marking)

    redirect_to @fraud_marking, notice: I18n.t("fraud_markings.notices.submitted_to_jdpi")
  rescue StandardError => e
    Rails.logger.error "[FraudMarkingsController] JDPI submission failed: #{e.message}"
    redirect_to @fraud_marking, alert: I18n.t("fraud_markings.errors.jdpi_submission_failed")
  end

  # Export fraud markings data
  def export
    @fraud_markings = filtered_markings.includes(:fraud_marking_logs)

    respond_to do |format|
      format.csv { send_csv_export }
      format.xlsx { send_xlsx_export }
    end
  end

  private

  def set_fraud_marking
    @fraud_marking = FraudMarking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to fraud_markings_path, alert: I18n.t("fraud_markings.errors.not_found")
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

  def filtered_markings
    scope = FraudMarking.all

    # Status filtering
    case @tab
    when "pending"
      scope = scope.pending_approval
    when "active"
      scope = scope.active
    when "rejected"
      scope = scope.where(status: "REJECTED")
    when "cancelled"
      scope = scope.where(status: "CANCELLED")
    when "all"
      # No additional filtering
    end

    # Additional filters
    scope = scope.by_status(@status_filter) if @status_filter.present?
    scope = scope.by_fraud_type(@fraud_type_filter) if @fraud_type_filter.present?
    scope = scope.by_risk_level(@risk_level_filter) if @risk_level_filter.present?

    # Date range filtering
    case @date_range
    when "7_days"
      scope = scope.created_after(7.days.ago)
    when "30_days"
      scope = scope.created_after(30.days.ago)
    when "90_days"
      scope = scope.created_after(90.days.ago)
    end

    # Search by PIX key
    if params[:search].present?
      scope = scope.by_pix_key(params[:search])
    end

    scope
  end

  def calculate_dashboard_stats
    {
      total_markings: FraudMarking.count,
      pending_approval: FraudMarking.pending_approval.count,
      active_markings: FraudMarking.active.count,
      high_priority: FraudMarking.high_risk.count,
      overdue: FraudMarking.overdue.count,
      today_created: FraudMarking.where("created_at >= ?", Time.current.beginning_of_day).count,
      avg_approval_time: calculate_avg_approval_time,
      success_rate: calculate_success_rate
    }
  end

  def calculate_critical_alerts
    [
      {
        type: "overdue",
        count: FraudMarking.overdue.count,
        message: I18n.t("fraud_markings.alerts.overdue_markings"),
        severity: "danger"
      },
      {
        type: "high_priority",
        count: FraudMarking.high_risk.pending_states.count,
        message: I18n.t("fraud_markings.alerts.high_priority_pending"),
        severity: "warning"
      },
      {
        type: "requires_approval",
        count: FraudMarking.requires_approval.pending_approval.count,
        message: I18n.t("fraud_markings.alerts.requires_approval"),
        severity: "info"
      }
    ].select { |alert| alert[:count] > 0 }
  end

  def calculate_timeline_data
    # Last 30 days data for charts
    30.days.ago.to_date.upto(Date.current).map do |date|
      {
        date: date,
        created: FraudMarking.where(created_at: date.beginning_of_day..date.end_of_day).count,
        approved: FraudMarking.where(approved_at: date.beginning_of_day..date.end_of_day).count,
        active: FraudMarking.where(
          status: "ACTIVE",
          updated_at: date.beginning_of_day..date.end_of_day
        ).count
      }
    end
  end

  def calculate_avg_approval_time
    approved_markings = FraudMarking.where.not(approved_at: nil)
    return 0 if approved_markings.empty?

    total_hours = approved_markings.sum do |marking|
      ((marking.approved_at - marking.created_at) / 1.hour).round(2)
    end

    (total_hours / approved_markings.count).round(2)
  end

  def calculate_success_rate
    total = FraudMarking.final_states.count
    return 0 if total == 0

    successful = FraudMarking.active.count
    ((successful.to_f / total) * 100).round(2)
  end

  # Permission checks

  def can_approve_marking?(marking)
    is_supervisor? && marking.can_be_approved?
  end

  def can_reject_marking?(marking)
    is_supervisor? && marking.can_be_rejected?
  end

  def can_cancel_marking?(marking)
    # Any authorized user can cancel, but only in valid states
    marking.can_be_cancelled?
  end

  def can_submit_marking?(marking)
    marking.can_be_submitted?
  end

  def require_supervisor_approval
    unless is_supervisor?
      redirect_to fraud_markings_path, alert: I18n.t("fraud_markings.errors.supervisor_required")
    end
  end

  def is_supervisor?
    # This should integrate with your actual permission system
    # For now, checking if user has supervisor role in session or claims
    current_user_roles.include?("fraud_supervisor") ||
    current_user_roles.include?("admin") ||
    session[:user_roles]&.include?("supervisor")
  end

  def current_user_identifier
    # Extract user identifier from JWT or session
    session[:user_email] || session[:user_id] || "system"
  end

  def current_user_roles
    # Extract roles from JWT claims or session
    session[:user_roles] || []
  end

  # Async processing methods

  def submit_to_jdpi_async(fraud_marking)
    FraudMarkingSubmissionJob.perform_later(fraud_marking.id)

    FraudMarkingLog.create_for_action!(
      fraud_marking: fraud_marking,
      action: "submitted_to_jdpi",
      user: current_user_identifier,
      message: "Fraud marking submitted to JDPI for processing",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  # Export methods

  def fraud_markings_json
    {
      markings: @fraud_markings.map do |marking|
        {
          id: marking.short_id,
          pix_key: marking.masked_pix_key_display,
          fraud_type: marking.fraud_type_description,
          status: marking.status_description,
          priority: marking.priority_level,
          created_at: marking.created_at.strftime("%d/%m/%Y %H:%M"),
          url: fraud_marking_path(marking)
        }
      end,
      stats: @dashboard_stats,
      alerts: @critical_alerts
    }
  end

  def send_csv_export
    csv_data = FraudMarkingExportService.new(@fraud_markings).to_csv
    filename = "fraud_markings_#{Date.current.strftime('%Y%m%d')}.csv"
    send_data csv_data, filename: filename, type: "text/csv"
  end

  def send_xlsx_export
    xlsx_data = FraudMarkingExportService.new(@fraud_markings).to_xlsx
    filename = "fraud_markings_#{Date.current.strftime('%Y%m%d')}.xlsx"
    send_data xlsx_data, filename: filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end
end

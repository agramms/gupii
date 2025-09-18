# frozen_string_literal: true

class DisputesController < AuthBaseController
  before_action :set_dispute, only: [ :show, :approve, :reject, :escalate, :assign, :cancel ]
  before_action :set_infraction_notification, only: [ :new, :create ]

  def index
    @tab = params[:tab] || "opened"

    # Dashboard stats for fraud team
    @dashboard_stats = calculate_dashboard_stats
    @critical_alerts = calculate_critical_alerts

    # Main dispute list with filtering
    @disputes = filtered_disputes.recent.limit(50)

    # Tab-specific counts
    @opened_count = Dispute.active.count
    @pending_count = Dispute.status_pending_customer_response.count
    @under_review_count = Dispute.status_under_internal_review.count
    @overdue_count = Dispute.overdue_customer_response.count
    @approaching_deadline_count = Dispute.approaching_deadline.count
  end

  def show
    @timeline = @dispute.timeline_summary
    @infraction_notification = @dispute.infraction_notification
  end

  def create
    @dispute = @infraction_notification.build_dispute(dispute_params)
    @dispute.created_by = current_user&.email || "system"

    if @dispute.save
      # Update infraction notification dispute status
      @infraction_notification.update!(dispute_status: "pending")

      redirect_to @dispute, notice: "Disputa criada com sucesso."
    else
      flash.now[:error] = @dispute.errors.full_messages
      render :new, status: :unprocessable_content
    end
  end

  def new
    unless @infraction_notification.can_be_disputed?
      flash[:error] = "Esta notificação não pode ser disputada."
      redirect_to @infraction_notification
      return
    end

    @dispute = @infraction_notification.build_dispute
  end

  def approve
    reviewer = current_user&.email || "system"
    resolution_notes = params[:resolution_notes].presence || "Disputa aprovada"
    next_actions = params[:next_actions]

    if @dispute.approve_dispute!(
      reviewer: reviewer,
      resolution_notes: resolution_notes,
      next_actions: next_actions
    )
      flash[:success] = "Disputa aprovada com sucesso."
    else
      flash[:error] = "Não foi possível aprovar a disputa."
    end

    redirect_to @dispute
  end

  def reject
    reviewer = current_user&.email || "system"
    resolution_notes = params[:resolution_notes].presence || "Disputa rejeitada"
    next_actions = params[:next_actions]

    if @dispute.reject_dispute!(
      reviewer: reviewer,
      resolution_notes: resolution_notes,
      next_actions: next_actions
    )
      flash[:success] = "Disputa rejeitada com sucesso."
    else
      flash[:error] = "Não foi possível rejeitar a disputa."
    end

    redirect_to @dispute
  end

  def escalate
    escalated_by = current_user&.email || "system"
    escalation_reason = params[:escalation_reason].presence || "Disputa escalada para revisão superior"
    assigned_to = params[:assigned_to]

    if @dispute.escalate!(
      escalated_by: escalated_by,
      escalation_reason: escalation_reason,
      assigned_to: assigned_to
    )
      flash[:success] = "Disputa escalada com sucesso."
    else
      flash[:error] = "Não foi possível escalar a disputa."
    end

    redirect_to @dispute
  end

  def assign
    assignee = params[:assignee].presence
    assigned_by = current_user&.email || "system"

    unless assignee
      flash[:error] = "Responsável deve ser informado."
      redirect_to @dispute
      return
    end

    if @dispute.assign_reviewer!(assignee: assignee, assigned_by: assigned_by)
      flash[:success] = "Disputa atribuída para #{assignee} com sucesso."
    else
      flash[:error] = "Não foi possível atribuir a disputa."
    end

    redirect_to @dispute
  end

  def cancel
    unless @dispute.can_be_cancelled?
      flash[:error] = "Esta disputa não pode ser cancelada no status atual."
      redirect_to @dispute
      return
    end

    if @dispute.update(status: :rejected, resolved_at: Time.current, resolution_notes: "Disputa cancelada pelo usuário")
      @dispute.infraction_notification.update!(dispute_status: "cancelled")
      flash[:success] = "Disputa cancelada com sucesso."
      redirect_to disputes_path
    else
      flash[:error] = "Não foi possível cancelar a disputa."
      redirect_to @dispute
    end
  end

  # API endpoint for auto-declining overdue disputes (background job)
  def auto_decline_overdue
    return render json: { error: "Unauthorized" }, status: :unauthorized unless authorized_system_user?

    count = Dispute.auto_decline_overdue!

    render json: {
      success: true,
      message: "Auto-declined #{count} overdue disputes",
      count: count,
    }
  end

  private

  def set_dispute
    # Try to find by full UUID first, then by short ID
    @dispute = Dispute.find_by(id: params[:id]) ||
               Dispute.joins(:infraction_notification)
                      .where(infraction_notifications: { short_id: params[:id] })
                      .first

    unless @dispute
      flash[:error] = "Disputa não encontrada."
      redirect_to disputes_path
    end
  end

  def set_infraction_notification
    # For nested routes, use the parent resource parameter
    infraction_id = params[:infraction_notification_id] || params.dig(:dispute, :infraction_notification_id)
    @infraction_notification = InfractionNotification.find_by_any_id(infraction_id)

    unless @infraction_notification
      flash[:error] = "Notificação de infração não encontrada."
      redirect_to infraction_notifications_path
    end
  end

  def dispute_params
    params.require(:dispute).permit(
      :dispute_type,
      :justification,
      :evidence_notes
    )
  end

  def search_params
    params.permit([
      :format,
      :tab,
      :search,
      :status,
      :dispute_type,
      :created_by,
      :assigned_to,
      :created_from,
      :created_to,
      :due_from,
      :due_to,
      :quick_filter,
      { q: [
        :justification_cont,
        :dispute_type_eq,
        :status_eq,
        :created_by_eq,
        :assigned_to_eq,
        :created_at_gteq,
        :created_at_lteq,
        :customer_response_due_at_gteq,
        :customer_response_due_at_lteq,
      ] },
      :page,
    ])
  end

  # Helper method for views to get permitted parameters
  def permitted_params_except(*keys)
    search_params.except(*keys)
  end
  helper_method :permitted_params_except

  # Dashboard helper methods
  def calculate_dashboard_stats
    {
      total_pending: Dispute.active.count,
      overdue_customer_response: Dispute.overdue_customer_response.count,
      approaching_deadlines: Dispute.approaching_deadline.count,
      under_review: Dispute.status_under_internal_review.count,
    }
  end

  def calculate_critical_alerts
    {
      auto_decline_candidates: Dispute.overdue_customer_response.count,
      high_priority_types: high_priority_dispute_count,
      escalated_disputes: Dispute.status_escalated.count,
    }
  end

  def filtered_disputes
    scope = Dispute.includes(:infraction_notification)

    # Tab filtering
    case @tab
    when "opened"
      scope = scope.active
    when "pending"
      scope = scope.status_pending_customer_response
    when "review"
      scope = scope.status_under_internal_review
    when "overdue"
      scope = scope.overdue_customer_response
    when "resolved"
      scope = scope.where(status: [ :approved, :rejected, :auto_declined ])
    when "all"
      # No additional filtering for 'all' tab
    end

    # Apply search filters
    scope = scope.joins(:infraction_notification)
                 .where("disputes.justification ILIKE ? OR infraction_notifications.pix_key ILIKE ? OR infraction_notifications.description ILIKE ?",
                       "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.by_dispute_type(params[:dispute_type]) if params[:dispute_type].present?
    scope = scope.by_created_by(params[:created_by]) if params[:created_by].present?
    scope = scope.where(assigned_to: params[:assigned_to]) if params[:assigned_to].present?

    # Date range filters
    scope = scope.where("disputes.created_at >= ?", Date.parse(params[:created_from])) if params[:created_from].present?
    scope = scope.where("disputes.created_at <= ?", Date.parse(params[:created_to]).end_of_day) if params[:created_to].present?

    # Due date filters
    scope = scope.where("disputes.customer_response_due_at >= ?", Date.parse(params[:due_from])) if params[:due_from].present?
    scope = scope.where("disputes.customer_response_due_at <= ?", Date.parse(params[:due_to]).end_of_day) if params[:due_to].present?

    # Quick filters
    case params[:quick_filter]
    when "overdue"
      scope = scope.overdue_customer_response
    when "approaching"
      scope = scope.approaching_deadline
    when "high_priority"
      scope = scope.where(dispute_type: [ :validity_challenge, :escalation_required ])
    end

    scope
  end

  def high_priority_dispute_count
    Dispute.active.where(dispute_type: [ :validity_challenge, :escalation_required ]).count
  end

  def authorized_system_user?
    # This would check for system-level authorization
    # For now, just check if it's an internal request
    request.headers["X-Internal-Request"] == "true" ||
    current_user&.has_role?(:system_admin)
  end
end

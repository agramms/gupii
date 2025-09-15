# frozen_string_literal: true

class Api::V1::DisputesController < Api::V1::BaseController
  before_action :set_dispute, only: [ :show, :approve, :reject, :escalate, :assign ]
  before_action :set_infraction_notification, only: [ :create ]

  def index
    disputes = filtered_disputes.recent.limit(params[:limit] || 50)

    render json: {
      success: true,
      data: disputes.as_json(
        include: {
          infraction_notification: {
            only: [ :id, :pix_key, :infraction_type, :status, :created_at ],
            methods: [ :masked_pix_key, :short_id ]
          }
        },
        methods: [ :days_until_deadline, :hours_until_deadline, :timeline_summary ]
      ),
      meta: build_meta_data(disputes)
    }
  end

  def show
    render json: {
      success: true,
      data: @dispute.as_json(
        include: {
          infraction_notification: {
            methods: [ :masked_pix_key, :short_id, :status_description ]
          }
        },
        methods: [ :timeline_summary, :days_until_deadline, :hours_until_deadline ]
      )
    }
  end

  def create
    @dispute = @infraction_notification.build_dispute(dispute_params)
    @dispute.created_by = api_user_identifier

    if @dispute.save
      # Update infraction notification dispute status
      @infraction_notification.update!(dispute_status: "pending")

      render json: {
        success: true,
        message: "Disputa criada com sucesso",
        data: @dispute.as_json(methods: [ :timeline_summary ])
      }, status: :created
    else
      render json: {
        success: false,
        errors: @dispute.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def approve
    resolution_notes = params[:resolution_notes].presence || "Disputa aprovada via API"
    next_actions = params[:next_actions]

    if @dispute.approve_dispute!(
      reviewer: api_user_identifier,
      resolution_notes: resolution_notes,
      next_actions: next_actions
    )
      render json: {
        success: true,
        message: "Disputa aprovada com sucesso",
        data: @dispute.reload.as_json(methods: [ :timeline_summary ])
      }
    else
      render json: {
        success: false,
        message: "Não foi possível aprovar a disputa"
      }, status: :unprocessable_entity
    end
  end

  def reject
    resolution_notes = params[:resolution_notes].presence || "Disputa rejeitada via API"
    next_actions = params[:next_actions]

    if @dispute.reject_dispute!(
      reviewer: api_user_identifier,
      resolution_notes: resolution_notes,
      next_actions: next_actions
    )
      render json: {
        success: true,
        message: "Disputa rejeitada com sucesso",
        data: @dispute.reload.as_json(methods: [ :timeline_summary ])
      }
    else
      render json: {
        success: false,
        message: "Não foi possível rejeitar a disputa"
      }, status: :unprocessable_entity
    end
  end

  def escalate
    escalation_reason = params[:escalation_reason].presence || "Disputa escalada via API"
    assigned_to = params[:assigned_to]

    if @dispute.escalate!(
      escalated_by: api_user_identifier,
      escalation_reason: escalation_reason,
      assigned_to: assigned_to
    )
      render json: {
        success: true,
        message: "Disputa escalada com sucesso",
        data: @dispute.reload.as_json(methods: [ :timeline_summary ])
      }
    else
      render json: {
        success: false,
        message: "Não foi possível escalar a disputa"
      }, status: :unprocessable_entity
    end
  end

  def assign
    assignee = params[:assignee].presence

    unless assignee
      render json: {
        success: false,
        message: "Responsável deve ser informado"
      }, status: :unprocessable_entity
      return
    end

    if @dispute.assign_reviewer!(assignee: assignee, assigned_by: api_user_identifier)
      render json: {
        success: true,
        message: "Disputa atribuída para #{assignee} com sucesso",
        data: @dispute.reload.as_json(methods: [ :timeline_summary ])
      }
    else
      render json: {
        success: false,
        message: "Não foi possível atribuir a disputa"
      }, status: :unprocessable_entity
    end
  end

  # Background job endpoint for auto-declining overdue disputes
  def auto_decline_overdue
    return render json: { success: false, error: "Unauthorized" }, status: :unauthorized unless authorized_system_request?

    count = Dispute.auto_decline_overdue!

    render json: {
      success: true,
      message: "Auto-declined #{count} overdue disputes",
      count: count
    }
  end

  # Get overdue disputes
  def overdue
    disputes = Dispute.overdue_customer_response.includes(:infraction_notification).recent

    render json: {
      success: true,
      data: disputes.as_json(
        include: {
          infraction_notification: {
            only: [ :id, :pix_key, :infraction_type, :status ],
            methods: [ :masked_pix_key, :short_id ]
          }
        },
        methods: [ :days_until_deadline, :hours_until_deadline ]
      ),
      count: disputes.count
    }
  end

  # Get disputes approaching deadline
  def approaching_deadline
    disputes = Dispute.approaching_deadline.includes(:infraction_notification).recent

    render json: {
      success: true,
      data: disputes.as_json(
        include: {
          infraction_notification: {
            only: [ :id, :pix_key, :infraction_type, :status ],
            methods: [ :masked_pix_key, :short_id ]
          }
        },
        methods: [ :days_until_deadline, :hours_until_deadline ]
      ),
      count: disputes.count
    }
  end

  # Get dispute statistics
  def stats
    stats = {
      total: Dispute.count,
      by_status: Dispute.group(:status).count,
      by_type: Dispute.group(:dispute_type).count,
      active: Dispute.active.count,
      overdue: Dispute.overdue_customer_response.count,
      approaching_deadline: Dispute.approaching_deadline.count,
      resolved_today: Dispute.where(resolved_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      auto_declined: Dispute.status_auto_declined.count
    }

    render json: {
      success: true,
      data: stats,
      generated_at: Time.current.iso8601
    }
  end

  private

  def set_dispute
    @dispute = Dispute.find_by(id: params[:id])

    unless @dispute
      render json: {
        success: false,
        message: "Disputa não encontrada"
      }, status: :not_found
    end
  end

  def set_infraction_notification
    infraction_id = params[:dispute][:infraction_notification_id] || params[:infraction_notification_id]
    @infraction_notification = InfractionNotification.find_by(id: infraction_id)

    unless @infraction_notification
      render json: {
        success: false,
        message: "Notificação de infração não encontrada"
      }, status: :not_found
    end
  end

  def dispute_params
    params.require(:dispute).permit(
      :dispute_type,
      :justification,
      :evidence_notes,
      additional_data: {}
    )
  end

  def filtered_disputes
    scope = Dispute.includes(:infraction_notification)

    # Status filtering
    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.by_dispute_type(params[:dispute_type]) if params[:dispute_type].present?
    scope = scope.by_created_by(params[:created_by]) if params[:created_by].present?

    # Date filtering
    scope = scope.where("disputes.created_at >= ?", Date.parse(params[:created_from])) if params[:created_from].present?
    scope = scope.where("disputes.created_at <= ?", Date.parse(params[:created_to]).end_of_day) if params[:created_to].present?

    # Due date filtering
    scope = scope.where("disputes.customer_response_due_at >= ?", Date.parse(params[:due_from])) if params[:due_from].present?
    scope = scope.where("disputes.customer_response_due_at <= ?", Date.parse(params[:due_to]).end_of_day) if params[:due_to].present?

    # Search filtering
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.joins(:infraction_notification)
                   .where("disputes.justification ILIKE ? OR infraction_notifications.pix_key ILIKE ? OR infraction_notifications.description ILIKE ?",
                         search_term, search_term, search_term)
    end

    # Quick filters
    case params[:filter]
    when "overdue"
      scope = scope.overdue_customer_response
    when "approaching"
      scope = scope.approaching_deadline
    when "active"
      scope = scope.active
    when "high_priority"
      scope = scope.where(dispute_type: [ :validity_challenge, :escalation_required ])
    end

    scope
  end

  def build_meta_data(disputes)
    {
      total_count: Dispute.count,
      filtered_count: disputes.count,
      page: params[:page] || 1,
      limit: params[:limit] || 50,
      stats: {
        pending: Dispute.status_pending_customer_response.count,
        under_review: Dispute.status_under_internal_review.count,
        overdue: Dispute.overdue_customer_response.count,
        approaching_deadline: Dispute.approaching_deadline.count
      }
    }
  end

  def api_user_identifier
    # This would typically extract from JWT token or API key
    current_api_user&.email || request.headers["X-API-User"] || "api_system"
  end

  def authorized_system_request?
    # Check for system-level authorization
    request.headers["X-Internal-Request"] == "true" ||
    request.headers["X-System-Token"] == Rails.application.credentials.system_token ||
    current_api_user&.has_role?(:system_admin)
  end
end

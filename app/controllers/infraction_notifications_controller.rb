# frozen_string_literal: true

class InfractionNotificationsController < AuthBaseController
  before_action :set_infraction_notification, only: [ :show, :cancel ]

  def index
    # Determine tab context - sent vs received infractions
    @tab = params[:tab] || "received"

    # Fraud team dashboard analytics
    @dashboard_stats = calculate_dashboard_stats
    @critical_alerts = calculate_critical_alerts

    # Main infraction list with filtering
    @infraction_notifications = filtered_notifications.recent.limit(50)

    # Additional analytics for fraud team
    @pending_count = InfractionNotification.pending.count
    @reviewing_count = InfractionNotification.where(status: "ANALYZING").count
    @expiring_today = expiring_today_count

    # Tab-specific counts
    @sent_count = InfractionNotification.where(created_by: [ "CUSTOMER_SERVICE", "CUSTOMER_EXPERIENCE" ]).count
    @received_count = InfractionNotification.where(created_by: "DICT_AUTOMATIC").count
  end

  def show
    @infraction_logs = @infraction_notification.infraction_logs.recent.limit(20)
  end

  def new
    @infraction_notification = InfractionNotification.new
    # Default to Customer Service for user-created notifications
    @infraction_notification.created_by = Jdpi::StatusCodes::InfractionSources::CUSTOMER_SERVICE
  end

  def create
    @infraction_notification = InfractionNotification.new(infraction_notification_params.merge(idempotency_key: SecureRandom.uuid))

    if @infraction_notification.save
      # Submit to JDPI if not created automatically by DICT
      unless @infraction_notification.created_by_dict_automatic?
        submit_to_jdpi_later(@infraction_notification)
      end

      redirect_to @infraction_notification, notice: "Notificação de infração criada com sucesso."
    else
      flash.now[:error] = @infraction_notification.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    reason = params[:reason].presence || "Cancelamento solicitado via interface web"
    cancelled_by = current_user&.email || "system"

    if @infraction_notification.soft_delete!(reason: reason, cancelled_by: cancelled_by)
      flash[:success] = "Notificação de infração cancelada com sucesso."
    else
      flash[:error] = "Não foi possível cancelar a notificação de infração."
    end

    redirect_to @infraction_notification
  end

  private

  def set_infraction_notification
    # Try to find by full UUID first, then by short ID
    @infraction_notification = InfractionNotification.find_by_any_id(params[:id]) ||
                               InfractionNotification.search_by_short_id(params[:id]).first

    unless @infraction_notification
      flash[:error] = "Notificação de infração não encontrada."
      redirect_to infraction_notifications_path
    end
  end

  def infraction_notification_params
    params.require(:infraction_notification).permit(
      :pix_key,
      :infraction_type,
      :description,
      :created_by,
      :evidence_data
    )
  end

  def search_params
    params.permit([
      :format,
      :tab,
      :search,
      :status,
      :priority,
      :infraction_type,
      :created_by,
      :created_from,
      :created_to,
      :expiring_from,
      :expiring_to,
      :quick_filter,
      { q: [
        :pix_key_cont,
        :infraction_type_eq,
        :status_eq,
        :created_by_eq,
        :description_cont,
        :created_at_gteq,
        :created_at_lteq,
        :submitted_at_gteq,
        :submitted_at_lteq,
      ] },
      :page,
    ])
  end

  # Helper method for views to get permitted parameters
  def permitted_params_except(*keys)
    search_params.except(*keys)
  end
  helper_method :permitted_params_except

  def submit_to_jdpi_later(infraction_notification)
    # This would typically be a background job
    # For now, we'll just log it
    Rails.logger.info "[InfractionNotification] Scheduling JDPI submission for notification #{infraction_notification.id}"

    # TODO: Implement background job to submit to JDPI
    # SubmitInfractionToJdpiJob.perform_later(infraction_notification)
  end

  # Fraud team dashboard helper methods
  def calculate_dashboard_stats
    {
      total_pending: InfractionNotification.pending.count,
      high_priority: high_priority_count,
      overdue: overdue_count,
      sla_at_risk: sla_at_risk_count,
    }
  end

  def calculate_critical_alerts
    {
      burning_deadlines: burning_deadlines_count,
      high_value_transactions: high_value_count,
      repeat_offenders: repeat_offenders_count,
    }
  end

  def filtered_notifications
    scope = InfractionNotification.all

    # Tab filtering - sent vs received
    case @tab
    when "sent"
      scope = scope.where(created_by: [ "CUSTOMER_SERVICE", "CUSTOMER_EXPERIENCE" ])
    when "received"
      scope = scope.where(created_by: "DICT_AUTOMATIC")
    end

    # Apply filters based on search params
    scope = scope.where("pix_key ILIKE ? OR description ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.by_created_by(params[:created_by]) if params[:created_by].present?
    scope = scope.by_infraction_type(params[:infraction_type]) if params[:infraction_type].present?

    # Date range filters
    scope = scope.where("created_at >= ?", Date.parse(params[:created_from])) if params[:created_from].present?
    scope = scope.where("created_at <= ?", Date.parse(params[:created_to]).end_of_day) if params[:created_to].present?

    # Expiring date filters (based on 48-hour deadline)
    if params[:expiring_from].present?
      expiring_from = Date.parse(params[:expiring_from])
      scope = scope.where("created_at <= ?", expiring_from + 48.hours)
    end

    if params[:expiring_to].present?
      expiring_to = Date.parse(params[:expiring_to])
      scope = scope.where("created_at >= ?", expiring_to + 48.hours)
    end

    # Quick stats filters
    case params[:quick_filter]
    when "pending"
      scope = scope.pending
    when "review"
      scope = scope.where(status: "ANALYZING")
    when "expiring"
      scope = scope.where("created_at BETWEEN ? AND ?", 48.hours.ago, 24.hours.ago)
    when "priority"
      scope = scope.where(
        "infraction_type IN (?) OR evidence_data->>'amount' > ? OR evidence_data->>'repeat_violation' = ?",
        [ "ACCOUNT_TAKEOVER", "SIM_SWAP" ],
        "10000",
        "true"
      )
    end

    scope
  end

  def high_priority_count
    # High priority: account takeover, high value, multiple violations
    InfractionNotification.pending.where(
      "infraction_type IN (?) OR evidence_data->>'amount' > ? OR evidence_data->>'repeat_violation' = ?",
      [ "ACCOUNT_TAKEOVER", "SIM_SWAP" ],
      "10000",
      "true"
    ).count
  end

  def overdue_count
    # Overdue: > 48 hours without response
    InfractionNotification.pending.where("created_at < ?", 48.hours.ago).count
  end

  def sla_at_risk_count
    # At risk: 24-48 hours without response
    InfractionNotification.pending.where(
      "created_at BETWEEN ? AND ?",
      48.hours.ago,
      24.hours.ago
    ).count
  end

  def burning_deadlines_count
    # Critical: < 6 hours to response deadline
    InfractionNotification.pending.where("created_at < ?", 42.hours.ago).count
  end

  def high_value_count
    # High value transactions > R$ 10,000
    InfractionNotification.pending.where("evidence_data->>'amount' > ?", "10000").count
  end

  def repeat_offenders_count
    # Same PIX key with multiple infractions
    InfractionNotification.pending
      .group(:pix_key)
      .having("COUNT(*) > 1")
      .count
      .keys
      .size
  end

  def expiring_today_count
    # Notifications that will expire today (within 24 hours)
    InfractionNotification.pending.where(
      "created_at BETWEEN ? AND ?",
      48.hours.ago,
      24.hours.ago
    ).count
  end
end

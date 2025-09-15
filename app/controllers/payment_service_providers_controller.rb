class PaymentServiceProvidersController < ApplicationController
  include Pagy::Backend

  before_action :set_payment_service_provider, only: [ :show ]
  before_action :set_search_params, only: [ :index ]

  # GET /payment_service_providers
  def index
    Rails.logger.info "[PSP Controller] Loading PSP index with params: #{search_params.inspect}"

    begin
      @psps = PaymentServiceProvider.all # Simplified for debugging
      @pagy, @psps = pagy(@psps, items: 20)

      # Dashboard metrics for the header
      @dashboard_summary = PspMetricsService.dashboard_data
      @health_alerts = PspMetricsService.health_alerts

      Rails.logger.info "[PSP Controller] Loaded #{@psps.count} PSPs for display"

      respond_to do |format|
        format.html
        format.json do
          render json: {
            psps: @psps.map { |psp| psp_summary_json(psp) },
            pagination: build_pagination_metadata(@pagy),
            dashboard: @dashboard_summary,
            alerts: @health_alerts
          }
        end
      end
    rescue => e
      Rails.logger.error "[PSP Controller] Index error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e # Re-raise for debugging
    end
  end

  # GET /payment_service_providers/1
  def show
    Rails.logger.info "[PSP Controller] Loading PSP details: #{@psp.display_id}"

    # Load related metrics for this PSP
    @sync_history = build_sync_history(@psp)
    @operational_metrics = build_operational_metrics(@psp)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          psp: psp_detailed_json(@psp),
          sync_history: @sync_history,
          operational_metrics: @operational_metrics
        }
      end
    end
  end

  # POST /payment_service_providers/sync
  def sync
    Rails.logger.info "[PSP Controller] Manual sync requested"

    sync_type = params[:sync_type] || "incremental"
    options = {
      collect_metrics: true,
      manual_trigger: true,
      triggered_by: current_user&.id || "anonymous"
    }

    case sync_type
    when "full"
      job = PspSyncJob.schedule_full_sync(options: options)
    when "incremental"
      job = PspSyncJob.schedule_incremental_sync(options: options)
    when "single"
      ispb = params[:ispb]
      unless ispb.present?
        return render json: { error: "ISPB is required for single PSP sync" }, status: :bad_request
      end
      job = PspSyncJob.schedule_single_psp_sync(ispb, options: options)
    else
      return render json: { error: "Invalid sync type: #{sync_type}" }, status: :bad_request
    end

    Rails.logger.info "[PSP Controller] Sync job scheduled: #{job.job_id}"

    respond_to do |format|
      format.html do
        flash[:success] = t("psp.sync.scheduled", sync_type: sync_type, job_id: job.job_id)
        redirect_to payment_service_providers_path
      end
      format.json do
        render json: {
          message: "#{sync_type.capitalize} sync scheduled successfully",
          job_id: job.job_id,
          sync_type: sync_type
        }, status: :accepted
      end
    end
  rescue => e
    Rails.logger.error "[PSP Controller] Sync scheduling failed: #{e.message}"

    respond_to do |format|
      format.html do
        flash[:error] = t("psp.sync.failed", error: e.message)
        redirect_to payment_service_providers_path
      end
      format.json do
        render json: { error: "Sync scheduling failed: #{e.message}" }, status: :internal_server_error
      end
    end
  end

  # GET /payment_service_providers/sync_status
  def sync_status
    status = PspSyncJob.last_sync_status

    render json: {
      last_success: status[:last_success],
      last_error: status[:last_error],
      overall_health: status[:last_success] &&
                     status[:last_success][:timestamp] > 24.hours.ago.iso8601 ? "healthy" : "stale"
    }
  end

  # GET /payment_service_providers/metrics
  def metrics
    Rails.logger.info "[PSP Controller] Metrics dashboard requested"

    @dashboard_data = PspMetricsService.dashboard_data
    @health_alerts = PspMetricsService.health_alerts

    respond_to do |format|
      format.html { render :metrics }
      format.json do
        render json: {
          dashboard: @dashboard_data,
          alerts: @health_alerts,
          generated_at: Time.current.iso8601
        }
      end
    end
  end

  # GET /payment_service_providers/health
  def health
    Rails.logger.info "[PSP Controller] Health check requested"

    begin
      # Quick health check
      total_count = PaymentServiceProvider.count
      needs_sync_count = PaymentServiceProvider.needs_sync.count
      failed_sync_count = PaymentServiceProvider.sync_failed.count

      health_score = 100
      health_score -= 20 if needs_sync_count > (total_count * 0.1) # More than 10% need sync
      health_score -= 30 if failed_sync_count > (total_count * 0.05) # More than 5% failed sync

      status = case health_score
      when 80..100 then "healthy"
      when 50..79 then "degraded"
      else "unhealthy"
      end

      render json: {
        status: status,
        health_score: health_score,
        total_psps: total_count,
        needs_sync: needs_sync_count,
        failed_sync: failed_sync_count,
        timestamp: Time.current.iso8601
      }, status: health_score >= 50 ? :ok : :service_unavailable

    rescue => e
      Rails.logger.error "[PSP Controller] Health check failed: #{e.message}"

      render json: {
        status: "error",
        error: e.message,
        timestamp: Time.current.iso8601
      }, status: :service_unavailable
    end
  end

  private

  def build_pagination_metadata(pagy)
    return {} unless pagy

    {
      current: pagy.page,
      per_page: pagy.vars[:items],
      total_pages: pagy.pages,
      total_count: pagy.count,
      has_next: pagy.next.present?,
      has_prev: pagy.prev.present?
    }
  rescue => e
    Rails.logger.error "[PSP Controller] Pagination metadata error: #{e.message}"
    {}
  end

  def set_payment_service_provider
    @psp = PaymentServiceProvider.find_by_any_id(params[:id]) ||
           PaymentServiceProvider.search_by_short_id(params[:id]).first

    unless @psp
      Rails.logger.warn "[PSP Controller] PSP not found: #{params[:id]}"
      respond_to do |format|
        format.html do
          flash[:error] = t("psp.not_found")
          redirect_to payment_service_providers_path
        end
        format.json { render json: { error: "PSP not found" }, status: :not_found }
      end
    end
  end

  def set_search_params
    @search_params = params.permit(:search, :status, :psp_type, :state, :pix_enabled,
                                  :regulatory_status, :sort, :direction, :page, :sync_status)
  end

  def search_params
    @search_params || {}
  end

  def build_psp_query
    query = PaymentServiceProvider.all

    # Text search
    if search_params[:search].present?
      search_term = search_params[:search]
      query = query.where(
        "name ILIKE ? OR short_name ILIKE ? OR ispb ILIKE ? OR contact_email ILIKE ?",
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      )
    end

    # Status filters
    query = query.where(status: search_params[:status]) if search_params[:status].present?
    query = query.where(psp_type: search_params[:psp_type]) if search_params[:psp_type].present?
    query = query.where(regulatory_status: search_params[:regulatory_status]) if search_params[:regulatory_status].present?
    query = query.where(pix_enabled: search_params[:pix_enabled] == "true") if search_params[:pix_enabled].present?

    # Geographic filter
    query = query.by_state(search_params[:state]) if search_params[:state].present?

    # Sync status filter
    case search_params[:sync_status]
    when "needs_sync"
      query = query.needs_sync
    when "sync_failed"
      query = query.sync_failed
    when "recently_updated"
      query = query.recently_updated
    end

    # Sorting
    sort_column = search_params[:sort].presence || "name"
    sort_direction = search_params[:direction].presence&.downcase == "desc" ? "DESC" : "ASC"

    # Validate sort column to prevent SQL injection
    valid_sort_columns = %w[name short_name ispb status psp_type created_at updated_at
                           last_sync_at total_transactions total_volume]

    if valid_sort_columns.include?(sort_column)
      query = query.order("#{sort_column} #{sort_direction}")
    else
      query = query.order("name ASC")
    end

    query
  end

  def build_sync_history(psp)
    {
      last_sync: psp.last_sync_at,
      last_successful_sync: psp.last_successful_sync_at,
      sync_attempts: psp.sync_attempts,
      sync_status: psp.sync_status,
      sync_health_score: psp.sync_health_score,
      last_sync_errors: psp.last_sync_errors&.last(5) || [], # Show recent errors
      data_source: psp.data_source
    }
  end

  def build_operational_metrics(psp)
    {
      operational_status: psp.operational_status,
      pix_services: psp.pix_services,
      total_transactions: psp.total_transactions,
      total_volume: psp.total_volume,
      last_transaction: psp.last_transaction_at,
      availability: psp.availability_percentage,
      avg_response_time: psp.avg_response_time_ms,
      error_count_24h: psp.error_count_24h,
      last_health_check: psp.last_health_check_at
    }
  end

  def psp_summary_json(psp)
    {
      id: psp.id,
      short_id: psp.short_id,
      display_id: psp.display_id,
      ispb: psp.ispb,
      name: psp.name,
      short_name: psp.short_name,
      status: psp.status,
      psp_type: psp.psp_type,
      regulatory_status: psp.regulatory_status,
      pix_enabled: psp.pix_enabled,
      operational_status: psp.operational_status,
      sync_status: psp.sync_status,
      last_sync_at: psp.last_sync_at,
      created_at: psp.created_at,
      updated_at: psp.updated_at
    }
  end

  def psp_detailed_json(psp)
    psp_summary_json(psp).merge({
      document_number: psp.document_number,
      document_type: psp.document_type,
      formatted_document: psp.formatted_document,
      services_offered: psp.services_offered,
      legal_address: psp.legal_address,
      city: psp.city,
      state: psp.state,
      postal_code: psp.postal_code,
      contact_phone: psp.contact_phone,
      contact_email: psp.contact_email,
      website: psp.website,
      authorization_number: psp.bacen_authorization_number,
      authorization_date: psp.authorization_date,
      authorization_expiry: psp.authorization_expiry,
      jdpi_metadata: psp.jdpi_metadata
    })
  end
end

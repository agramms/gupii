# frozen_string_literal: true

module Api
  module V1
    class PaymentServiceProvidersController < Api::V1::BaseController
      before_action :set_payment_service_provider, only: [ :show ]
      before_action :validate_pagination_params, only: [ :index ]

      # GET /api/v1/payment_service_providers
      def index
        Rails.logger.info "[PSP API] Loading PSPs with params: #{filter_params.inspect}"

        @psps = build_psp_query
        @pagy, @psps = pagy(@psps, items: per_page)

        render json: {
          data: @psps.map { |psp| psp_api_json(psp) },
          meta: {
            pagination: pagy_metadata(@pagy),
            total_count: @pagy.count,
            page: @pagy.page,
            per_page: @pagy.items,
            total_pages: @pagy.pages,
          },
          links: {
            self: api_v1_payment_service_providers_url(request.query_parameters),
            first: api_v1_payment_service_providers_url(request.query_parameters.merge(page: 1)),
            last: api_v1_payment_service_providers_url(request.query_parameters.merge(page: @pagy.pages)),
            prev: @pagy.prev ? api_v1_payment_service_providers_url(request.query_parameters.merge(page: @pagy.prev)) : nil,
            next: @pagy.next ? api_v1_payment_service_providers_url(request.query_parameters.merge(page: @pagy.next)) : nil,
          },
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] Index request failed: #{e.message}"
        render_api_error("Failed to load PSPs: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/1
      def show
        Rails.logger.info "[PSP API] Loading PSP details: #{@psp.display_id}"

        render json: {
          data: psp_detailed_api_json(@psp),
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] Show request failed: #{e.message}"
        render_api_error("Failed to load PSP details: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/search
      def search
        search_term = params[:q]&.strip

        if search_term.blank?
          return render_api_error("Search query 'q' parameter is required", :bad_request)
        end

        if search_term.length < 2
          return render_api_error("Search query must be at least 2 characters", :bad_request)
        end

        Rails.logger.info "[PSP API] Search request: '#{search_term}'"

        # Search across multiple fields
        @psps = PaymentServiceProvider.where(
          "name ILIKE ? OR short_name ILIKE ? OR ispb ILIKE ? OR contact_email ILIKE ?",
          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
        )

        # Apply additional filters if provided
        @psps = apply_api_filters(@psps)

        # Limit search results to prevent overload
        @pagy, @psps = pagy(@psps, items: [ per_page, 50 ].min)

        render json: {
          data: @psps.map { |psp| psp_api_json(psp) },
          meta: {
            search_query: search_term,
            pagination: pagy_metadata(@pagy),
            total_matches: @pagy.count,
          },
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] Search failed: #{e.message}"
        render_api_error("Search failed: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/by_ispb/12345678
      def by_ispb
        ispb = params[:ispb]

        unless ispb.present? && ispb.match?(/\A\d{8}\z/)
          return render_api_error("Invalid ISPB format. Must be 8 digits.", :bad_request)
        end

        Rails.logger.info "[PSP API] ISPB lookup: #{ispb}"

        @psp = PaymentServiceProvider.find_by(ispb: ispb)

        if @psp
          render json: {
            data: psp_detailed_api_json(@psp),
            generated_at: Time.current.iso8601,
          }, status: :ok
        else
          render_api_error("PSP with ISPB #{ispb} not found", :not_found)
        end

      rescue => e
        Rails.logger.error "[PSP API] ISPB lookup failed: #{e.message}"
        render_api_error("ISPB lookup failed: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/active
      def active
        Rails.logger.info "[PSP API] Loading active PSPs"

        @psps = PaymentServiceProvider.active
        @psps = apply_api_filters(@psps)
        @pagy, @psps = pagy(@psps, items: per_page)

        render json: {
          data: @psps.map { |psp| psp_api_json(psp) },
          meta: {
            filter: "active",
            pagination: pagy_metadata(@pagy),
            total_active: @pagy.count,
          },
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] Active PSPs request failed: #{e.message}"
        render_api_error("Failed to load active PSPs: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/pix_enabled
      def pix_enabled
        Rails.logger.info "[PSP API] Loading PIX-enabled PSPs"

        @psps = PaymentServiceProvider.pix_enabled.active
        @psps = apply_api_filters(@psps)
        @pagy, @psps = pagy(@psps, items: per_page)

        render json: {
          data: @psps.map { |psp| psp_api_json(psp) },
          meta: {
            filter: "pix_enabled",
            pagination: pagy_metadata(@pagy),
            total_pix_enabled: @pagy.count,
          },
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] PIX-enabled PSPs request failed: #{e.message}"
        render_api_error("Failed to load PIX-enabled PSPs: #{e.message}", :internal_server_error)
      end

      # GET /api/v1/payment_service_providers/stats
      def stats
        Rails.logger.info "[PSP API] PSP statistics requested"

        cache_key = "psp_api_stats_#{Date.current}"

        stats = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          {
            total_psps: PaymentServiceProvider.count,
            active_psps: PaymentServiceProvider.active.count,
            pix_enabled_psps: PaymentServiceProvider.pix_enabled.count,
            pix_adoption_rate: PaymentServiceProvider.pix_adoption_rate,
            by_status: PaymentServiceProvider.group(:status).count,
            by_regulatory_status: PaymentServiceProvider.group(:regulatory_status).count,
            by_psp_type: PaymentServiceProvider.group(:psp_type).count,
            by_state: PaymentServiceProvider.where.not(state: nil).group(:state).count,
            last_sync: PaymentServiceProvider.maximum(:last_sync_at),
            data_freshness: {
              synced_today: PaymentServiceProvider.where("last_sync_at > ?", 24.hours.ago).count,
              needs_sync: PaymentServiceProvider.needs_sync.count,
              sync_failed: PaymentServiceProvider.sync_failed.count,
            },
          }
        end

        render json: {
          data: stats,
          meta: {
            cached: Rails.cache.exist?(cache_key),
            cache_expires_at: 1.hour.from_now.iso8601,
          },
          generated_at: Time.current.iso8601,
        }, status: :ok

      rescue => e
        Rails.logger.error "[PSP API] Stats request failed: #{e.message}"
        render_api_error("Failed to generate statistics: #{e.message}", :internal_server_error)
      end

      private

      def set_payment_service_provider
        @psp = PaymentServiceProvider.find_by_any_id(params[:id]) ||
               PaymentServiceProvider.search_by_short_id(params[:id]).first

        unless @psp
          Rails.logger.warn "[PSP API] PSP not found: #{params[:id]}"
          render_api_error("PSP not found", :not_found)
        end
      end

      def build_psp_query
        query = PaymentServiceProvider.all
        query = apply_api_filters(query)
        query = apply_api_sorting(query)
        query
      end

      def apply_api_filters(query)
        # Status filters
        query = query.where(status: filter_params[:status]) if filter_params[:status].present?
        query = query.where(psp_type: filter_params[:psp_type]) if filter_params[:psp_type].present?
        query = query.where(regulatory_status: filter_params[:regulatory_status]) if filter_params[:regulatory_status].present?

        # Boolean filters
        if filter_params[:pix_enabled].present?
          query = query.where(pix_enabled: filter_params[:pix_enabled] == "true")
        end

        if filter_params[:active_only] == "true"
          query = query.active
        end

        # Geographic filter
        query = query.by_state(filter_params[:state]) if filter_params[:state].present?

        # Date filters
        if filter_params[:created_after].present?
          begin
            date = Date.parse(filter_params[:created_after])
            query = query.where("created_at >= ?", date.beginning_of_day)
          rescue ArgumentError
            # Invalid date format - ignore filter
          end
        end

        if filter_params[:updated_after].present?
          begin
            date = Date.parse(filter_params[:updated_after])
            query = query.where("updated_at >= ?", date.beginning_of_day)
          rescue ArgumentError
            # Invalid date format - ignore filter
          end
        end

        query
      end

      def apply_api_sorting(query)
        sort_column = filter_params[:sort].presence || "name"
        sort_direction = filter_params[:direction].presence&.downcase == "desc" ? "DESC" : "ASC"

        # API-specific valid sort columns (more restrictive than web interface)
        valid_sort_columns = %w[name short_name ispb status psp_type created_at updated_at]

        if valid_sort_columns.include?(sort_column)
          query.order("#{sort_column} #{sort_direction}")
        else
          query.order("name ASC")
        end
      end

      def filter_params
        @filter_params ||= params.permit(:status, :psp_type, :regulatory_status, :pix_enabled,
                                       :active_only, :state, :sort, :direction, :page, :per_page,
                                       :created_after, :updated_after)
      end

      def per_page
        per_page = filter_params[:per_page].to_i
        per_page = 20 if per_page <= 0
        [ per_page, 100 ].min # Maximum 100 records per page
      end

      def validate_pagination_params
        page = params[:page].to_i
        per_page_param = params[:per_page].to_i

        if page < 0
          return render_api_error("Invalid page number. Must be positive.", :bad_request)
        end

        if per_page_param > 100
          render_api_error("Per page limit exceeded. Maximum 100 records per page.", :bad_request)
        end
      end

      def psp_api_json(psp)
        {
          id: psp.id,
          short_id: psp.short_id,
          ispb: psp.ispb,
          name: psp.name,
          short_name: psp.short_name,
          status: psp.status,
          psp_type: psp.psp_type,
          regulatory_status: psp.regulatory_status,
          pix_enabled: psp.pix_enabled,
          operational_status: psp.operational_status,
          state: psp.state,
          city: psp.city,
          contact_email: psp.contact_email,
          website: psp.website,
          services_offered: psp.services_offered,
          last_sync_at: psp.last_sync_at,
          created_at: psp.created_at,
          updated_at: psp.updated_at,
        }
      end

      def psp_detailed_api_json(psp)
        psp_api_json(psp).merge({
          document_number: psp.document_number,
          document_type: psp.document_type,
          legal_address: psp.legal_address,
          postal_code: psp.postal_code,
          contact_phone: psp.contact_phone,
          authorization_number: psp.bacen_authorization_number,
          authorization_date: psp.authorization_date,
          authorization_expiry: psp.authorization_expiry,
          sync_status: psp.sync_status,
          sync_health_score: psp.sync_health_score,
          last_successful_sync_at: psp.last_successful_sync_at,
          data_source: psp.data_source,
          total_transactions: psp.total_transactions,
          total_volume: psp.total_volume,
          last_transaction_at: psp.last_transaction_at,
          availability_percentage: psp.availability_percentage,
          avg_response_time_ms: psp.avg_response_time_ms,
        })
      end
    end
  end
end

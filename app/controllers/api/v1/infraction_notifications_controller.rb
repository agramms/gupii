# frozen_string_literal: true

module Api
  module V1
    class InfractionNotificationsController < Api::V1::BaseController
      before_action :set_infraction_notification, only: [ :show, :cancel ]

      def index
        notifications = InfractionNotification.recent

        # Apply search filters if provided
        notifications = filter_notifications(notifications, search_params)

        # Apply pagination
        limit = [ params[:limit].to_i, 100 ].min
        limit = 20 if limit <= 0
        offset = [ params[:offset].to_i, 0 ].max

        @infraction_notifications = notifications.limit(limit).offset(offset)
        total_count = notifications.count

        render json: {
          notifications: @infraction_notifications.map(&method(:notification_json)),
          pagination: {
            total: total_count,
            limit: limit,
            offset: offset,
            has_more: total_count > (offset + limit),
          },
        }
      end

      def show
        return render json: { error: "Notification not found" }, status: :not_found unless @infraction_notification

        render json: {
          notification: notification_json(@infraction_notification, include_logs: true),
        }
      end

      def create
        @infraction_notification = InfractionNotification.new(infraction_notification_params)

        if @infraction_notification.save
          # Submit to JDPI if not created automatically by DICT
          unless @infraction_notification.created_by_dict_automatic?
            submit_to_jdpi_later(@infraction_notification)
          end

          render json: {
            notification: notification_json(@infraction_notification),
            message: "Infraction notification created successfully",
          }, status: :created
        else
          render json: {
            errors: @infraction_notification.errors.full_messages,
          }, status: :unprocessable_content
        end
      end

      def cancel
        return render json: { error: "Notification not found" }, status: :not_found unless @infraction_notification

        reason = params[:reason].presence || "Cancelled via API"
        cancelled_by = params[:cancelled_by].presence || "api_user"

        if @infraction_notification.soft_delete!(reason: reason, cancelled_by: cancelled_by)
          render json: {
            notification: notification_json(@infraction_notification),
            message: "Infraction notification cancelled successfully",
          }
        else
          render json: {
            error: "Unable to cancel infraction notification",
            details: @infraction_notification.can_be_cancelled? ? "Unknown error" : "Notification cannot be cancelled in current status",
          }, status: :unprocessable_content
        end
      end

      private

      def set_infraction_notification
        @infraction_notification = InfractionNotification.find_by_any_id(params[:id]) ||
                                   InfractionNotification.search_by_short_id(params[:id]).first
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
        params.permit(
          :pix_key_cont,
          :infraction_type_eq,
          :status_eq,
          :created_by_eq,
          :description_cont,
          :created_at_gteq,
          :created_at_lteq,
          :submitted_at_gteq,
          :submitted_at_lteq,
          :limit,
          :offset
        ).to_h.with_indifferent_access
      end

      def notification_json(notification, include_logs: false)
        json = {
          id: notification.id,
          short_id: notification.display_id,
          pix_key: notification.pix_key,
          masked_pix_key: notification.masked_pix_key,
          pix_key_type: notification.pix_key_type,
          infraction_type: notification.infraction_type,
          infraction_type_description: notification.infraction_type_description,
          description: notification.description,
          status: notification.status,
          created_by: notification.created_by,
          created_by_description: notification.created_by_description,
          evidence_data: notification.evidence_data,
          jdpi_notification_id: notification.jdpi_notification_id,
          submitted_at: notification.submitted_at,
          last_status_change_at: notification.last_status_change_at,
          processed_at: notification.processed_at,
          cancelled_at: notification.cancelled_at,
          cancellation_reason: notification.cancellation_reason,
          analysis_result: notification.analysis_result,
          analysis_notes: notification.analysis_notes,
          created_at: notification.created_at,
          updated_at: notification.updated_at,
          can_be_cancelled: notification.can_be_cancelled?,
          can_be_analyzed: notification.can_be_analyzed?,
          pending: notification.pending?,
          completed: notification.completed?,
          days_since_submission: notification.days_since_submission,
          overdue_for_analysis: notification.overdue_for_analysis?,
        }

        if include_logs
          json[:logs] = notification.infraction_logs.recent.limit(50).map do |log|
            {
              id: log.id,
              short_id: log.display_id,
              level: log.level,
              message: log.message,
              metadata: log.metadata,
              occurred_at: log.occurred_at,
            }
          end
        end

        json
      end

      def filter_notifications(notifications, filters)
        notifications = notifications.where("pix_key ILIKE ?", "%#{filters[:pix_key_cont]}%") if filters[:pix_key_cont].present?
        notifications = notifications.by_infraction_type(filters[:infraction_type_eq]) if filters[:infraction_type_eq].present?
        notifications = notifications.by_status(filters[:status_eq]) if filters[:status_eq].present?
        notifications = notifications.by_created_by(filters[:created_by_eq]) if filters[:created_by_eq].present?
        notifications = notifications.where("description ILIKE ?", "%#{filters[:description_cont]}%") if filters[:description_cont].present?
        notifications = notifications.where("created_at >= ?", filters[:created_at_gteq]) if filters[:created_at_gteq].present?
        notifications = notifications.where("created_at <= ?", filters[:created_at_lteq]) if filters[:created_at_lteq].present?
        notifications = notifications.where("submitted_at >= ?", filters[:submitted_at_gteq]) if filters[:submitted_at_gteq].present?
        notifications = notifications.where("submitted_at <= ?", filters[:submitted_at_lteq]) if filters[:submitted_at_lteq].present?

        notifications
      end

      def submit_to_jdpi_later(infraction_notification)
        # This would typically be a background job
        Rails.logger.info "[API] Scheduling JDPI submission for notification #{infraction_notification.id}"

        # TODO: Implement background job to submit to JDPI
        # SubmitInfractionToJdpiJob.perform_later(infraction_notification)
      end
    end
  end
end

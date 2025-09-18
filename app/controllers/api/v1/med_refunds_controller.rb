# frozen_string_literal: true

class Api::V1::MedRefundsController < ApiBaseController
  before_action :authenticate_api_client

  # POST /api/v1/med_refunds
  # Submit a MED refund request
  def create
    service = Jdpi::MedService.new(med_params)
    result = service.call

    if result[:success]
      render json: {
        success: true,
        data: result[:data],
        message: "Refund request submitted successfully",
      }, status: :accepted
    else
      render json: {
        success: false,
        errors: result[:errors],
        message: "Refund request failed",
      }, status: :unprocessable_content
    end
  end

  # GET /api/v1/med_refunds/:jdpi_request_id
  # Query refund status
  def show
    jdpi_request_id = params[:id]
    idempotency_key = params[:idempotency_key]

    result = Jdpi::MedService.query_refund_status(
      jdpi_request_id: jdpi_request_id,
      idempotency_key: idempotency_key,
    )

    if result[:success]
      render json: {
        success: true,
        data: result[:data],
      }
    else
      render json: {
        success: false,
        errors: result[:errors],
        message: "Status query failed",
      }, status: :unprocessable_content
    end
  end

  # GET /api/v1/med_refunds/reasons
  # List available refund reasons
  def reasons
    result = Jdpi::MedService.list_refund_reasons

    if result[:success]
      render json: {
        success: true,
        data: result[:data],
      }
    else
      render json: {
        success: false,
        errors: result[:errors],
        message: "Failed to retrieve refund reasons",
      }, status: :unprocessable_content
    end
  end

  # GET /api/v1/med_refunds/credit/:end_to_end_id
  # Query refund credit status
  def credit_status
    end_to_end_id = params[:end_to_end_id]

    result = Jdpi::MedService.query_refund_credit(
      end_to_end_id: end_to_end_id,
    )

    if result[:success]
      render json: {
        success: true,
        data: result[:data],
      }
    else
      render json: {
        success: false,
        errors: result[:errors],
        message: "Credit status query failed",
      }, status: :unprocessable_content
    end
  end

  # POST /api/v1/med_refunds/:jdpi_request_id/poll
  # Start polling for refund status updates
  def poll
    jdpi_request_id = params[:id]
    idempotency_key = params[:idempotency_key]

    polling_service = Jdpi::MedPollingService.new(
      jdpi_request_id: jdpi_request_id,
      idempotency_key: idempotency_key,
    )

    result = polling_service.poll_once

    if result[:success]
      data = result[:data]

      # Check if transaction is complete
      if transaction_complete?(data)
        render json: {
          success: true,
          status: "completed",
          data: data,
          message: "Transaction completed",
        }
      else
        render json: {
          success: true,
          status: "processing",
          data: data,
          polling_info: data[:polling_info],
          message: "Transaction still processing",
        }
      end
    else
      render json: {
        success: false,
        status: "error",
        errors: result[:errors],
        retry_info: result[:retry_info],
      }, status: :unprocessable_content
    end
  end

  private

  def med_params
    params.require(:refund).permit(
      :end_to_end_id_original,
      :refund_amount,
      :refund_code,
      :refund_description,
      :client_info,
      :client_authorization_token,
      fraud_analysis_data: {},
    )
  end

  def transaction_complete?(status_data)
    stj_dpi = status_data["stJdPi"]&.to_i
    stj_dpi_proc = status_data["stJdPiProc"]&.to_i

    # Final success states
    return true if stj_dpi == 9 || stj_dpi_proc == 9

    # Final error states
    return true if stj_dpi == -1 || stj_dpi_proc.in?([ 7, 8 ])

    false
  end
end

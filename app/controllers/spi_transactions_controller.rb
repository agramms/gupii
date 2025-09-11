# frozen_string_literal: true

# Controller for SPI Transaction Lookup functionality
# Provides a form-based interface to query SPI transactions by End-to-End ID
# No database persistence - direct API consultation only
class SpiTransactionsController < AuthBaseController
  before_action :validate_end_to_end_id_format, only: [:index], if: -> { params[:end_to_end_id].present? }

  # Display search form and results
  # GET /spi_transactions?end_to_end_id=E12345...
  def index
    @transaction_data = nil
    @error_message = nil
    
    if params[:end_to_end_id].present?
      lookup_transaction
    end
  end

  private

  # Perform SPI transaction lookup
  def lookup_transaction
    begin
      Rails.logger.info "[SPI Transactions] User #{current_user&.email || 'anonymous'} looking up E2E ID: #{params[:end_to_end_id]}"
      
      @transaction_data = Jdpi::SpiTransactionService.lookup(params[:end_to_end_id].strip.upcase)
      
      Rails.logger.info "[SPI Transactions] Successful lookup for E2E ID: #{params[:end_to_end_id]}"
      
    rescue Jdpi::SpiTransactionService::InvalidEndToEndIdError => e
      @error_message = e.message
      Rails.logger.warn "[SPI Transactions] Invalid E2E ID format: #{params[:end_to_end_id]} - #{e.message}"
      
    rescue Jdpi::SpiTransactionService::TransactionNotFoundError => e
      @error_message = "Transação não encontrada para o End-to-End ID informado. Verifique se o ID está correto."
      Rails.logger.info "[SPI Transactions] Transaction not found for E2E ID: #{params[:end_to_end_id]}"
      
    rescue Jdpi::SpiTransactionService::SpiApiError => e
      @error_message = "Erro na consulta à API SPI: #{e.message}. Tente novamente em alguns instantes."
      Rails.logger.error "[SPI Transactions] SPI API error for E2E ID #{params[:end_to_end_id]}: #{e.message}"
      
    rescue StandardError => e
      @error_message = "Erro interno do sistema. Nossa equipe foi notificada. Tente novamente em alguns instantes."
      Rails.logger.error "[SPI Transactions] Unexpected error for E2E ID #{params[:end_to_end_id]}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # In production, you might want to send this to an error tracking service
      # Sentry.capture_exception(e, extra: { end_to_end_id: params[:end_to_end_id] })
    end
  end

  # Validate End-to-End ID format before making API call
  def validate_end_to_end_id_format
    end_to_end_id = params[:end_to_end_id].to_s.strip.upcase
    
    # PIX E2E ID format: E + 8 digits (ISPB) + 12 digits (yyyyMMddHHmm) + 11 alphanumeric
    unless end_to_end_id.match?(/\AE\d{8}\d{12}[A-Za-z0-9]{11}\z/)
      @error_message = "Formato de End-to-End ID inválido. O ID deve ter exatamente 32 caracteres no formato: E + 8 dígitos (ISPB) + 12 dígitos (data/hora UTC) + 11 caracteres alfanuméricos."
      Rails.logger.warn "[SPI Transactions] Invalid E2E ID format: #{params[:end_to_end_id]}"
      return
    end

    # Length validation
    if end_to_end_id.length != 32
      @error_message = "End-to-End ID deve ter exatamente 32 caracteres. Informado: #{end_to_end_id.length} caracteres."
      return
    end

    # Update params with cleaned version
    params[:end_to_end_id] = end_to_end_id
  end

  # Helper method for views to get sanitized parameters
  def permitted_params
    params.permit(:end_to_end_id, :format)
  end
  helper_method :permitted_params

  # Check if there's a valid lookup result
  def has_transaction_data?
    @transaction_data.present? && @error_message.blank?
  end
  helper_method :has_transaction_data?

  # Check if there's an error message to display
  def has_error?
    @error_message.present?
  end
  helper_method :has_error?

  # Format currency values for display
  def format_currency(value)
    return 'N/A' unless value.present?
    
    begin
      # Assuming value comes in centavos from API
      real_value = value.to_f / 100
      number_with_precision(real_value, precision: 2, delimiter: '.', separator: ',')
    rescue StandardError
      value.to_s
    end
  end
  helper_method :format_currency

  # Format datetime for Brazilian locale
  def format_datetime(datetime_string)
    return 'N/A' unless datetime_string.present?
    
    begin
      Time.parse(datetime_string).strftime("%d/%m/%Y às %H:%M:%S")
    rescue StandardError
      datetime_string
    end
  end
  helper_method :format_datetime

  # Get status badge color class
  def transaction_status_class(transaction_data)
    return 'bg-gray-100 text-gray-800' unless transaction_data.present?

    if transaction_data['liquidated']
      'bg-green-100 text-green-800'
    elsif transaction_data['processing']
      'bg-yellow-100 text-yellow-800'
    else
      'bg-red-100 text-red-800'
    end
  end
  helper_method :transaction_status_class

  # Get transaction type display text
  def transaction_type_display(transaction_data)
    return 'N/A' unless transaction_data.present?
    
    transaction_data['transactionType'] || 'Tipo Desconhecido'
  end
  helper_method :transaction_type_display

  # Get transaction status display text
  def transaction_status_display(transaction_data)
    return 'N/A' unless transaction_data.present?
    
    transaction_data['transactionStatus'] || 'Status Desconhecido'
  end
  helper_method :transaction_status_display

  # Format ISPB for display (mask middle digits)
  def format_ispb(ispb)
    return 'N/A' unless ispb.present?
    
    # Convert to string to handle both string and integer inputs
    ispb_str = ispb.to_s
    return ispb_str unless ispb_str.length == 8
    
    "#{ispb_str[0..2]}*****#{ispb_str[-1]}"
  end
  helper_method :format_ispb

  # Format CNPJ for display (mask middle digits)
  def format_cnpj(cnpj)
    return 'N/A' unless cnpj.present?
    
    # Convert to string to handle both string and integer inputs
    cnpj_str = cnpj.to_s
    return cnpj_str unless cnpj_str.length == 14
    
    "#{cnpj_str[0..2]}.***.***/****-#{cnpj_str[-2..-1]}"
  end
  helper_method :format_cnpj

  # Get priority badge color
  def priority_badge_class(is_priority)
    is_priority ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
  end
  helper_method :priority_badge_class

  # Check if transaction has agent information (cash-out scenarios)
  def has_agent_info?(transaction_data)
    transaction_data.present? && (
      transaction_data['agentModality'].present? || 
      transaction_data['agentType'].present? ||
      transaction_data['ispbPss'].present?
    )
  end
  helper_method :has_agent_info?
end
# frozen_string_literal: true

module Jdpi
  # Service for consulting SPI transactions via JDPI API
  # Endpoint: GET /jdpi/spi/api/v2/lancamento/{endToEndId}
  # Documentation: JDPI API 5.2.1 - Section 8.4.7
  class SpiTransactionService < BaseService
    API_VERSION = 'v2'
    ENDPOINT_PATH = 'spi/api'
    
    # Custom exceptions for SPI transaction errors
    class TransactionNotFoundError < StandardError; end
    class InvalidEndToEndIdError < StandardError; end
    class SpiApiError < StandardError; end
    
    class << self
      # Consult transaction by End-to-End ID
      # @param end_to_end_id [String] 32-character E2E ID
      # @return [Hash] Transaction data from SPI
      # @raise [InvalidEndToEndIdError] if E2E ID format is invalid
      # @raise [TransactionNotFoundError] if transaction not found
      # @raise [SpiApiError] if API returns error
      def lookup(end_to_end_id)
        validate_end_to_end_id!(end_to_end_id)
        
        begin
          response = make_request(end_to_end_id)
          normalize_response(response)
        rescue Net::HTTPError => e
          handle_http_error(e, end_to_end_id)
        rescue StandardError => e
          Rails.logger.error "[SPI Transaction Service] Unexpected error for E2E ID #{end_to_end_id}: #{e.message}"
          raise SpiApiError, "Erro interno na consulta SPI"
        end
      end

      private

      # Validate End-to-End ID format
      # Format: E + 8 digits (ISPB) + 12 digits (yyyyMMddHHmm) + 11 alphanumeric characters
      def validate_end_to_end_id!(end_to_end_id)
        return if end_to_end_id.present? && end_to_end_id.match?(/\AE\d{8}\d{12}[A-Za-z0-9]{11}\z/)
        
        raise InvalidEndToEndIdError, "Formato de End-to-End ID inválido. Deve ter 32 caracteres no formato: E + 8 dígitos (ISPB) + 12 dígitos (data/hora UTC yyyyMMddHHmm) + 11 caracteres alfanuméricos"
      end

      # Make HTTP request to SPI API
      def make_request(end_to_end_id)
        url = build_api_url(end_to_end_id)
        headers = build_headers
        
        Rails.logger.info "[SPI Transaction Service] Consulting E2E ID: #{end_to_end_id}"
        
        response = http_client.get(url, headers)
        
        Rails.logger.info "[SPI Transaction Service] API Response Status: #{response.code}"
        
        case response.code
        when 200
          JSON.parse(response.body)
        when 404
          raise TransactionNotFoundError, "Transação não encontrada para o End-to-End ID: #{end_to_end_id}"
        when 400
          raise InvalidEndToEndIdError, "End-to-End ID inválido ou malformado"
        when 401, 403
          raise SpiApiError, "Erro de autenticação na API SPI"
        when 500, 502, 503, 504
          raise SpiApiError, "Erro interno da API SPI. Tente novamente"
        else
          raise SpiApiError, "Erro inesperado da API SPI (#{response.code})"
        end
      end

      # Build complete API URL
      def build_api_url(end_to_end_id)
        base_url = Rails.application.credentials.dig(:jdpi, :base_url) || 'https://api.jdpi.bcb.gov.br'
        "#{base_url}/jdpi/#{ENDPOINT_PATH}/#{API_VERSION}/lancamento/#{end_to_end_id}"
      end

      # Build request headers
      def build_headers
        token = Rails.application.credentials.dig(:jdpi, :access_token)
        
        {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'User-Agent' => "Gupii-SPI-Client/#{Rails.application.class.module_parent_name.downcase}"
        }
      end

      # Normalize API response to consistent format
      def normalize_response(api_response)
        {
          # Primary identifiers
          'endToEndId' => api_response['endToEndId'],
          'endToEndIdOriginal' => api_response['endToEndIdOriginal'],
          
          # Transaction status and type
          'transactionType' => normalize_transaction_type(api_response['tpLanc']),
          'transactionStatus' => normalize_transaction_status(api_response['stLanc']),
          'liquidated' => api_response['stLanc'] == 0,
          'processing' => api_response['stLanc'] == 9,
          
          # Institution information
          'ispbPspDireto' => api_response['ispbPspDireto'],
          'ispbOrigemLanc' => api_response['ispbOrigemLanc'],
          'cnpjIniciadorPagamento' => api_response['cnpjIniciadorPagamento'],
          'ispbPss' => api_response['ispbPss'],
          
          # Payment information
          'paymentInitiationType' => normalize_payment_initiation(api_response['tpIniciacao']),
          'paymentPriority' => api_response['prioridadePagamento'] == 0 ? 'Prioritário' : 'Normal',
          'paymentPriorityType' => normalize_priority_type(api_response['tpPrioridadePagamento']),
          'paymentPurpose' => normalize_purpose(api_response['finalidade']),
          
          # Agent information (for cash-out scenarios)
          'agentModality' => normalize_agent_modality(api_response['modalidadeAgente']),
          'agentType' => normalize_agent_type(api_response['tpAgente']),
          
          # Technical information
          'sourceMessage' => api_response['nomeMsgOrigem'],
          'statusDateTime' => api_response['dtHrSituacao'],
          
          # Raw data for debugging
          'raw_api_response' => api_response
        }
      end

      # Normalize transaction type (tpLanc)
      def normalize_transaction_type(tp_lanc)
        case tp_lanc
        when 0 then 'Crédito'
        when 1 then 'Débito'
        else 'Desconhecido'
        end
      end

      # Normalize transaction status (stLanc)
      def normalize_transaction_status(st_lanc)
        case st_lanc
        when 0 then 'Liquidada e Contabilizada'
        when 1 then 'Não Liquidada (Informativo)'
        when 9 then 'Em Processamento'
        else 'Status Desconhecido'
        end
      end

      # Normalize payment initiation type (tpIniciacao)
      def normalize_payment_initiation(tp_iniciacao)
        case tp_iniciacao
        when 0 then 'Manual'
        when 1 then 'Chave PIX'
        when 2 then 'QR Code Estático'
        when 3 then 'QR Code Dinâmico'
        when 6 then 'Iniciação de Transação (SITP)'
        when 8 then 'PIX Automático'
        when 9 then 'PIX por Aproximação Dinâmico'
        else 'Tipo Desconhecido'
        end
      end

      # Normalize priority type (tpPrioridadePagamento)
      def normalize_priority_type(tp_prioridade)
        case tp_prioridade
        when 0 then 'Pagamento Prioritário'
        when 1 then 'Pagamento sob Análise Antifraude'
        when 2 then 'Pagamento Agendado'
        else 'Tipo de Prioridade Desconhecido'
        end
      end

      # Normalize payment purpose (finalidade)
      def normalize_purpose(finalidade)
        case finalidade
        when 0 then 'Compra ou Transferência'
        when 1 then 'PIX Troco'
        when 2 then 'PIX Saque'
        when 3 then 'Reembolso'
        else 'Finalidade Desconhecida'
        end
      end

      # Normalize agent modality (modalidadeAgente)
      def normalize_agent_modality(modalidade)
        return nil if modalidade.nil?
        
        case modalidade
        when 0 then 'Facilitador de Saque'
        when 1 then 'Estabelecimento Comercial'
        when 2 then 'Pessoa Jurídica/Correspondente'
        else 'Modalidade Desconhecida'
        end
      end

      # Normalize agent type (tpAgente)
      def normalize_agent_type(tp_agente)
        return nil if tp_agente.nil?
        
        case tp_agente
        when 0 then 'Contraparte STR'
        when 1 then 'Contraparte SELIC'
        else 'Tipo de Agente Desconhecido'
        end
      end

      # Handle HTTP errors with proper logging and user-friendly messages
      def handle_http_error(error, end_to_end_id)
        Rails.logger.error "[SPI Transaction Service] HTTP Error for E2E ID #{end_to_end_id}: #{error.class} - #{error.message}"
        
        case error
        when Net::TimeoutError
          raise SpiApiError, "Timeout na consulta SPI. Tente novamente"
        when Net::HTTPUnauthorized
          raise SpiApiError, "Erro de autenticação na API SPI"
        when Net::HTTPNotFound
          raise TransactionNotFoundError, "Transação não encontrada para o End-to-End ID: #{end_to_end_id}"
        when Net::HTTPServerError
          raise SpiApiError, "Erro interno da API SPI. Tente novamente"
        else
          raise SpiApiError, "Erro de comunicação com a API SPI"
        end
      end

      # HTTP client with appropriate timeout settings
      def http_client
        @http_client ||= Net::HTTP
      end
    end
  end
end
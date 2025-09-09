module Jdpi
  # Service for managing Payment Service Provider (PSP) data from JDPI API
  # Handles fetching participant information with comprehensive monitoring
  class PspService < BaseService
    attr_reader :psp_data, :synced_count, :created_count, :updated_count, :error_count
    
    def initialize(attributes = {})
      super
      @psp_data = []
      @synced_count = 0
      @created_count = 0
      @updated_count = 0
      @error_count = 0
      @start_time = Time.current
    end
    
    # Fetch all PSPs from JDPI and update local database
    def sync_all_psps
      Rails.logger.info "[JDPI PSP] Starting comprehensive PSP sync"
      track_metric("psp.sync.started", 1)
      
      begin
        response_data = fetch_psp_list
        return self if response_data.nil?
        
        @psp_data = extract_psp_records(response_data)
        process_psp_data
        
        log_sync_summary
        track_sync_metrics
        
        Rails.logger.info "[JDPI PSP] Sync completed successfully"
        track_metric("psp.sync.completed", 1)
        
      rescue StandardError => e
        handle_sync_error(e)
      end
      
      self
    end
    
    # Fetch specific PSP by ISPB
    def fetch_psp(ispb)
      Rails.logger.info "[JDPI PSP] Fetching PSP data for ISPB: #{ispb}"
      track_metric("psp.fetch.single.started", 1)
      
      start_time = Time.current
      
      begin
        response_data = execute_request(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar/#{ispb}")
        return self if response_data.nil?
        
        @psp_data = [response_data]
        process_psp_data
        
        duration = (Time.current - start_time) * 1000
        track_metric("psp.fetch.single.duration", duration)
        track_metric("psp.fetch.single.success", 1)
        
        Rails.logger.info "[JDPI PSP] Successfully fetched PSP: #{ispb}"
        
      rescue StandardError => e
        track_metric("psp.fetch.single.error", 1)
        add_error("Failed to fetch PSP #{ispb}: #{e.message}")
        Rails.logger.error "[JDPI PSP] Error fetching PSP #{ispb}: #{e.message}"
      end
      
      self
    end
    
    # Health check for PSP service
    def health_check
      Rails.logger.info "[JDPI PSP] Performing health check"
      track_metric("psp.health_check.started", 1)
      
      start_time = Time.current
      
      begin
        # Simple endpoint to test connectivity and auth
        response_data = execute_request(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar", 
                                      body: nil, 
                                      idempotent: false)
        
        duration = (Time.current - start_time) * 1000
        track_metric("psp.health_check.duration", duration)
        
        if response_data
          track_metric("psp.health_check.success", 1)
          Rails.logger.info "[JDPI PSP] Health check passed"
        else
          track_metric("psp.health_check.failed", 1)
          Rails.logger.warn "[JDPI PSP] Health check failed - no response data"
        end
        
      rescue StandardError => e
        track_metric("psp.health_check.error", 1)
        add_error("Health check failed: #{e.message}")
        Rails.logger.error "[JDPI PSP] Health check error: #{e.message}"
      end
      
      self
    end
    
    private
    
    def fetch_psp_list
      Rails.logger.info "[JDPI PSP] Fetching complete PSP list from JDPI"
      start_time = Time.current
      
      # JDPI API endpoint for participant list
      response_data = execute_request(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar", 
                                    body: nil, 
                                    idempotent: false)
      
      duration = (Time.current - start_time) * 1000
      track_metric("psp.api.fetch_list.duration", duration)
      
      if response_data
        track_metric("psp.api.fetch_list.success", 1)
        Rails.logger.info "[JDPI PSP] Successfully fetched PSP list"
      else
        track_metric("psp.api.fetch_list.error", 1)
        Rails.logger.error "[JDPI PSP] Failed to fetch PSP list"
      end
      
      response_data
    end
    
    def extract_psp_records(response_data)
      # Handle different possible response formats from JDPI
      case response_data
      when Hash
        if response_data.key?("participants")
          response_data["participants"]
        elsif response_data.key?("data")
          response_data["data"]
        else
          [response_data] # Single participant
        end
      when Array
        response_data
      else
        Rails.logger.warn "[JDPI PSP] Unexpected response format: #{response_data.class}"
        []
      end
    rescue StandardError => e
      Rails.logger.error "[JDPI PSP] Error extracting PSP records: #{e.message}"
      track_metric("psp.data.extraction_error", 1)
      []
    end
    
    def process_psp_data
      return if @psp_data.empty?
      
      Rails.logger.info "[JDPI PSP] Processing #{@psp_data.length} PSP records"
      track_metric("psp.records.total", @psp_data.length)
      
      @psp_data.each_with_index do |psp_record, index|
        begin
          process_single_psp(psp_record)
        rescue StandardError => e
          @error_count += 1
          track_metric("psp.processing.error", 1)
          Rails.logger.error "[JDPI PSP] Error processing record #{index + 1}: #{e.message}"
          add_error("Failed to process PSP record: #{e.message}")
        end
      end
      
      @synced_count = @created_count + @updated_count
    end
    
    def process_single_psp(psp_record)
      ispb = psp_record["ispb"] || psp_record["ISPB"]
      return unless ispb.present?
      
      existing_psp = PaymentServiceProvider.find_by(ispb: ispb)
      
      if existing_psp
        update_existing_psp(existing_psp, psp_record)
      else
        create_new_psp(psp_record)
      end
    end
    
    def create_new_psp(psp_record)
      Rails.logger.info "[JDPI PSP] Creating new PSP: #{psp_record['ispb']}"
      
      psp = PaymentServiceProvider.new(map_jdpi_fields(psp_record))
      psp.data_source = 'jdpi'
      psp.last_sync_at = Time.current
      psp.last_successful_sync_at = Time.current
      psp.sync_attempts = 1
      
      if psp.save
        @created_count += 1
        track_metric("psp.records.created", 1)
        Rails.logger.info "[JDPI PSP] Created PSP: #{psp.display_id} (#{psp.name})"
      else
        track_metric("psp.records.create_failed", 1)
        Rails.logger.error "[JDPI PSP] Failed to create PSP #{psp_record['ispb']}: #{psp.errors.full_messages.join(', ')}"
        add_error("Failed to create PSP #{psp_record['ispb']}: #{psp.errors.full_messages.join(', ')}")
      end
    end
    
    def update_existing_psp(psp, psp_record)
      Rails.logger.debug "[JDPI PSP] Updating existing PSP: #{psp.ispb}"
      
      # Check if data has actually changed
      new_attributes = map_jdpi_fields(psp_record)
      has_changes = new_attributes.any? { |key, value| psp.send(key) != value }
      
      psp.assign_attributes(new_attributes) if has_changes
      psp.last_sync_at = Time.current
      psp.sync_attempts = (psp.sync_attempts || 0) + 1
      
      if psp.save
        psp.update_column(:last_successful_sync_at, Time.current)
        
        if has_changes
          @updated_count += 1
          track_metric("psp.records.updated", 1)
          Rails.logger.info "[JDPI PSP] Updated PSP: #{psp.display_id} (#{psp.name})"
        else
          track_metric("psp.records.no_changes", 1)
          Rails.logger.debug "[JDPI PSP] No changes for PSP: #{psp.display_id}"
        end
      else
        track_metric("psp.records.update_failed", 1)
        Rails.logger.error "[JDPI PSP] Failed to update PSP #{psp.ispb}: #{psp.errors.full_messages.join(', ')}"
        add_error("Failed to update PSP #{psp.ispb}: #{psp.errors.full_messages.join(', ')}")
      end
    end
    
    def map_jdpi_fields(psp_record)
      # Map JDPI API response fields to our model attributes
      {
        ispb: psp_record["ispb"] || psp_record["ISPB"],
        name: psp_record["name"] || psp_record["nomeExtensao"],
        short_name: psp_record["shortName"] || psp_record["nomeReduzido"],
        document_number: extract_document_number(psp_record),
        document_type: extract_document_type(psp_record),
        status: map_status(psp_record["status"]),
        psp_type: psp_record["type"] || psp_record["tipoParticipante"] || "unknown",
        services_offered: extract_services(psp_record),
        pix_enabled: extract_pix_status(psp_record),
        regulatory_status: map_regulatory_status(psp_record),
        legal_address: psp_record["address"] || psp_record["endereco"],
        city: psp_record["city"] || psp_record["cidade"],
        state: psp_record["state"] || psp_record["uf"],
        contact_phone: psp_record["phone"] || psp_record["telefone"],
        contact_email: psp_record["email"],
        website: psp_record["website"] || psp_record["site"],
        jdpi_metadata: psp_record.except("ispb", "name", "shortName"), # Store original data
        jdpi_status: psp_record["status"]
      }.compact
    end
    
    def extract_document_number(psp_record)
      # Try different possible field names
      doc = psp_record["documentNumber"] || psp_record["cnpj"] || psp_record["cpf"]
      doc&.gsub(/\D/, '') # Remove non-digits
    end
    
    def extract_document_type(psp_record)
      doc_number = extract_document_number(psp_record)
      return 'CNPJ' unless doc_number
      
      doc_number.length == 14 ? 'CNPJ' : 'CPF'
    end
    
    def extract_services(psp_record)
      services = psp_record["services"] || psp_record["servicos"] || []
      services = [services] unless services.is_a?(Array)
      services.compact
    end
    
    def extract_pix_status(psp_record)
      # Check various possible indicators
      pix_status = psp_record["pixEnabled"] || 
                   psp_record["habilitadoPix"] ||
                   psp_record["pixStatus"]
      
      case pix_status
      when true, "enabled", "ativo", "active"
        true
      when false, "disabled", "inativo", "inactive"
        false
      else
        # Default to true if services include PIX
        services = extract_services(psp_record)
        services.any? { |service| service.to_s.downcase.include?('pix') }
      end
    end
    
    def map_status(jdpi_status)
      case jdpi_status&.downcase
      when "ativo", "active", "operational"
        "active"
      when "inativo", "inactive"
        "inactive"
      when "suspenso", "suspended"
        "suspended"
      when "encerrado", "terminated"
        "terminated"
      else
        "active" # Default status
      end
    end
    
    def map_regulatory_status(psp_record)
      status = psp_record["regulatoryStatus"] || psp_record["situacaoRegulamentar"]
      
      case status&.downcase
      when "autorizado", "authorized"
        "authorized"
      when "provisorio", "provisional"
        "provisional"
      when "suspenso", "suspended"
        "suspended"
      when "revogado", "revoked"
        "revoked"
      else
        "authorized" # Default
      end
    end
    
    def handle_sync_error(error)
      @error_count += 1
      duration = (Time.current - @start_time) * 1000
      
      track_metric("psp.sync.error", 1)
      track_metric("psp.sync.duration", duration)
      
      add_error("Sync failed: #{error.message}")
      Rails.logger.error "[JDPI PSP] Sync error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
    end
    
    def log_sync_summary
      duration = (Time.current - @start_time) * 1000
      
      Rails.logger.info "[JDPI PSP] Sync Summary:"
      Rails.logger.info "  Total Records: #{@psp_data.length}"
      Rails.logger.info "  Created: #{@created_count}"
      Rails.logger.info "  Updated: #{@updated_count}"
      Rails.logger.info "  Errors: #{@error_count}"
      Rails.logger.info "  Duration: #{duration.round(2)}ms"
    end
    
    def track_sync_metrics
      duration = (Time.current - @start_time) * 1000
      
      track_metric("psp.sync.duration", duration)
      track_metric("psp.records.processed", @psp_data.length)
      track_metric("psp.records.synced", @synced_count)
      track_metric("psp.records.created", @created_count)
      track_metric("psp.records.updated", @updated_count)
      track_metric("psp.records.errors", @error_count)
      
      # Success rate metric
      total_processed = @psp_data.length
      success_rate = total_processed > 0 ? ((@synced_count.to_f / total_processed) * 100).round(2) : 100.0
      track_metric("psp.sync.success_rate", success_rate)
    end
    
    def track_metric(metric_name, value, tags = {})
      begin
        # Use StatsD client if available (configured in the observability stack)
        if defined?(::StatsD) && ::StatsD.respond_to?(:gauge)
          case metric_name
          when /\.(duration|success_rate)$/
            ::StatsD.gauge("gupii.jdpi.#{metric_name}", value, tags: tags)
          when /\.(started|completed|error|success|failed)$/
            ::StatsD.increment("gupii.jdpi.#{metric_name}", tags: tags)
          else
            ::StatsD.gauge("gupii.jdpi.#{metric_name}", value, tags: tags)
          end
        end
        
        # Also log as structured data for analysis
        Rails.logger.info "[JDPI PSP Metric] #{metric_name}: #{value} #{tags.any? ? tags.inspect : ''}"
        
      rescue StandardError => e
        # Don't let metrics collection break the main functionality
        Rails.logger.warn "[JDPI PSP] Metrics tracking error: #{e.message}"
      end
    end
    
    def default_scopes
      ["auth"] # PSP data is managed through DICT API
    end
  end
end
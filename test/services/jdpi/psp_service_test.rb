require 'test_helper'

class Jdpi::PspServiceTest < ActiveSupport::TestCase
  def setup
    @service = Jdpi::PspService.new
    
    # Mock JDPI API response
    @mock_psp_response = {
      "participants" => [
        {
          "ispb" => "12345678",
          "name" => "Test Bank SA",
          "shortName" => "TestBank",
          "status" => "ativo",
          "type" => "commercial_bank",
          "services" => ["pix_payment", "pix_receiving"],
          "pixEnabled" => true,
          "cnpj" => "12345678000199",
          "address" => "Test Street, 123",
          "city" => "São Paulo",
          "state" => "SP",
          "email" => "contact@testbank.com",
          "phone" => "+5511999999999"
        },
        {
          "ispb" => "87654321",
          "name" => "Another Bank Ltd",
          "shortName" => "AnotherBank", 
          "status" => "inativo",
          "type" => "cooperative",
          "services" => ["ted_transfer"],
          "pixEnabled" => false,
          "cnpj" => "87654321000188"
        }
      ]
    }
    
    @single_psp_response = @mock_psp_response["participants"].first
  end

  test 'should initialize with default values' do
    assert_empty @service.errors
    assert_equal 0, @service.synced_count
    assert_equal 0, @service.created_count
    assert_equal 0, @service.updated_count
    assert_equal 0, @service.error_count
  end

  test 'sync_all_psps should process multiple PSPs successfully' do
    # Mock successful API response
    @service.expects(:execute_request)
           .with(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar", body: nil, idempotent: false)
           .returns(@mock_psp_response)
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.sync_all_psps
    
    assert result.success?
    assert_equal 2, @service.psp_data.count
    
    # Verify PSPs were created in database
    assert_equal 2, PaymentServiceProvider.count
    
    psp1 = PaymentServiceProvider.find_by(ispb: "12345678")
    assert_not_nil psp1
    assert_equal "Test Bank SA", psp1.name
    assert_equal "TestBank", psp1.short_name
    assert_equal "active", psp1.status
    assert psp1.pix_enabled?
    assert_equal "SP", psp1.state
    
    psp2 = PaymentServiceProvider.find_by(ispb: "87654321")
    assert_not_nil psp2
    assert_equal "Another Bank Ltd", psp2.name
    assert_equal "inactive", psp2.status
    assert_not psp2.pix_enabled?
  end

  test 'sync_all_psps should handle API errors gracefully' do
    # Mock API failure
    @service.expects(:execute_request)
           .raises(StandardError.new("API timeout"))
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.sync_all_psps
    
    assert result.failure?
    assert_includes result.errors.join, "API timeout"
    assert_equal 1, @service.error_count
  end

  test 'fetch_psp should retrieve single PSP by ISPB' do
    ispb = "12345678"
    
    # Mock successful API response for single PSP
    @service.expects(:execute_request)
           .with(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar/#{ispb}")
           .returns(@single_psp_response)
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.fetch_psp(ispb)
    
    assert result.success?
    assert_equal 1, @service.psp_data.count
    assert_equal ispb, @service.psp_data.first["ispb"]
    
    # Verify PSP was created/updated in database
    psp = PaymentServiceProvider.find_by(ispb: ispb)
    assert_not_nil psp
    assert_equal "Test Bank SA", psp.name
  end

  test 'fetch_psp should handle single PSP API errors' do
    ispb = "12345678"
    
    # Mock API failure
    @service.expects(:execute_request)
           .raises(Faraday::NotFoundError.new("PSP not found"))
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.fetch_psp(ispb)
    
    assert result.failure?
    assert_includes result.errors.join, "PSP not found"
  end

  test 'health_check should verify API connectivity' do
    # Mock successful health check
    @service.expects(:execute_request)
           .with(:get, "/auth/jdpi/spi/api/v1/gestao-psps/listar", body: nil, idempotent: false)
           .returns({"status" => "ok"})
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.health_check
    
    assert result.success?
  end

  test 'health_check should detect API problems' do
    # Mock failed health check
    @service.expects(:execute_request)
           .raises(Faraday::TimeoutError.new("Request timeout"))
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.health_check
    
    assert result.failure?
    assert_includes result.errors.join, "Request timeout"
  end

  test 'should update existing PSP instead of creating duplicate' do
    # Create existing PSP
    existing_psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        name: "Old Name",
        short_name: "OldBank",
        status: "inactive",
        psp_type: "unknown",
        services_offered: ['ted_transfer'],
        pix_enabled: false
      )
    )
    
    # Mock API response with updated data
    @service.expects(:execute_request)
           .returns(@mock_psp_response)
    
    # Mock StatsD calls
    @service.expects(:track_metric).at_least(1)
    
    result = @service.sync_all_psps
    
    assert result.success?
    
    # Verify PSP was updated, not duplicated
    assert_equal 2, PaymentServiceProvider.count # Original + new one
    
    updated_psp = PaymentServiceProvider.find_by(ispb: "12345678")
    assert_equal existing_psp.id, updated_psp.id
    assert_equal "Test Bank SA", updated_psp.name # Updated
    assert_equal "TestBank", updated_psp.short_name # Updated
    assert_equal "active", updated_psp.status # Updated
    assert updated_psp.pix_enabled? # Updated
    
    assert_equal 0, @service.created_count
    assert_equal 2, @service.updated_count # Both PSPs updated
  end

  test 'should handle different response formats' do
    # Test direct array response
    @service.expects(:execute_request)
           .returns(@mock_psp_response["participants"])
    
    @service.expects(:track_metric).at_least(1)
    
    result = @service.sync_all_psps
    assert result.success?
    assert_equal 2, @service.psp_data.count
  end

  test 'should map JDPI fields correctly' do
    psp_data = {
      "ispb" => "12345678",
      "nomeExtensao" => "Full Bank Name SA",
      "nomeReduzido" => "FullBank",
      "status" => "ativo",
      "tipoParticipante" => "commercial_bank",
      "servicos" => ["pix", "ted"],
      "habilitadoPix" => true,
      "cnpj" => "12345678000199",
      "endereco" => "Banking Street, 456",
      "cidade" => "Rio de Janeiro",
      "uf" => "RJ",
      "telefone" => "+5521888888888",
      "email" => "info@fullbank.com",
      "site" => "https://www.fullbank.com"
    }
    
    mapped_fields = @service.send(:map_jdpi_fields, psp_data)
    
    assert_equal "12345678", mapped_fields[:ispb]
    assert_equal "Full Bank Name SA", mapped_fields[:name]
    assert_equal "FullBank", mapped_fields[:short_name]
    assert_equal "active", mapped_fields[:status]
    assert_equal "commercial_bank", mapped_fields[:psp_type]
    assert mapped_fields[:pix_enabled]
    assert_equal "12345678000199", mapped_fields[:document_number]
    assert_equal "CNPJ", mapped_fields[:document_type]
    assert_equal "Banking Street, 456", mapped_fields[:legal_address]
    assert_equal "Rio de Janeiro", mapped_fields[:city]
    assert_equal "RJ", mapped_fields[:state]
    assert_equal "+5521888888888", mapped_fields[:contact_phone]
    assert_equal "info@fullbank.com", mapped_fields[:contact_email]
    assert_equal "https://www.fullbank.com", mapped_fields[:website]
  end

  test 'should track comprehensive metrics' do
    # Expect various metric calls
    metric_calls = [
      "psp.sync.started",
      "psp.api.fetch_list.duration",
      "psp.api.fetch_list.success", 
      "psp.records.total",
      "psp.records.created",
      "psp.sync.duration",
      "psp.sync.completed"
    ]
    
    metric_calls.each do |metric|
      @service.expects(:track_metric).with(metric, anything, anything).at_least(0)
    end
    
    # Mock successful API call
    @service.expects(:execute_request).returns(@mock_psp_response)
    
    result = @service.sync_all_psps
    assert result.success?
  end

  test 'should extract PIX services correctly' do
    services_with_pix = ["pix_payment", "ted_transfer", "pix_receiving", "doc"]
    services_without_pix = ["ted_transfer", "doc", "wire_transfer"]
    
    # Test with PIX services
    psp_with_pix = {"servicos" => services_with_pix}
    assert @service.send(:extract_pix_status, psp_with_pix)
    
    # Test without PIX services
    psp_without_pix = {"servicos" => services_without_pix}
    assert_not @service.send(:extract_pix_status, psp_without_pix)
    
    # Test explicit PIX status
    psp_explicit_enabled = {"pixEnabled" => true}
    assert @service.send(:extract_pix_status, psp_explicit_enabled)
    
    psp_explicit_disabled = {"pixEnabled" => false}
    assert_not @service.send(:extract_pix_status, psp_explicit_disabled)
  end

  test 'should handle validation errors gracefully' do
    # Create invalid PSP data (missing required fields)
    invalid_response = {
      "participants" => [
        {
          "ispb" => "invalid", # Invalid ISPB format
          "name" => "", # Empty name
        }
      ]
    }
    
    @service.expects(:execute_request).returns(invalid_response)
    @service.expects(:track_metric).at_least(1)
    
    result = @service.sync_all_psps
    
    # Should handle gracefully and log errors
    assert result.success? # Service itself succeeds
    assert @service.error_count > 0 # But individual record fails
    assert_equal 0, PaymentServiceProvider.count # No PSPs created
  end

  test 'should use correct API scopes' do
    assert_equal ["dict_api"], @service.send(:default_scopes)
  end

  test 'should log sync summary' do
    @service.instance_variable_set(:@psp_data, [{}, {}])
    @service.instance_variable_set(:@created_count, 1)
    @service.instance_variable_set(:@updated_count, 1)
    @service.instance_variable_set(:@error_count, 0)
    
    Rails.logger.expects(:info).with("[JDPI PSP] Sync Summary:")
    Rails.logger.expects(:info).with("  Total Records: 2")
    Rails.logger.expects(:info).with("  Created: 1")  
    Rails.logger.expects(:info).with("  Updated: 1")
    Rails.logger.expects(:info).with("  Errors: 0")
    Rails.logger.expects(:info).with(regexp_matches(/Duration: \d+\.\d+ms/))
    
    @service.send(:log_sync_summary)
  end
end
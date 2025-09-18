# frozen_string_literal: true

require "test_helper"

class PaymentServiceProviderTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = valid_psp_attributes
    @psp = PaymentServiceProvider.new(@valid_attributes)
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @psp.valid?
  end

  test "should require ispb" do
    @psp.ispb = nil
    assert_not @psp.valid?
    assert_includes @psp.errors[:ispb], "não pode ficar em branco"
  end

  test "should validate ispb format" do
    @psp.ispb = "1234567" # Only 7 digits
    assert_not @psp.valid?
    assert_includes @psp.errors[:ispb], "must be 8 digits"

    @psp.ispb = "123456789" # 9 digits
    assert_not @psp.valid?
    assert_includes @psp.errors[:ispb], "must be 8 digits"

    @psp.ispb = "1234567a" # Contains letter
    assert_not @psp.valid?
    assert_includes @psp.errors[:ispb], "must be 8 digits"
  end

  test "should require unique ispb" do
    @psp.save!
    duplicate_psp = PaymentServiceProvider.new(@valid_attributes)
    assert_not duplicate_psp.valid?
    assert_includes duplicate_psp.errors[:ispb], "já está em uso"
  end

  test "should require name" do
    @psp.name = nil
    assert_not @psp.valid?
    assert_includes @psp.errors[:name], "não pode ficar em branco"

    @psp.name = "A" # Too short
    assert_not @psp.valid?
    assert_includes @psp.errors[:name], "é muito curto (mínimo: 2 caracteres)"
  end

  test "should validate status" do
    valid_statuses = %w[active inactive suspended terminated]
    valid_statuses.each do |status|
      @psp.status = status
      assert @psp.valid?, "#{status} should be valid"
    end

    @psp.status = "invalid_status"
    assert_not @psp.valid?
    assert_includes @psp.errors[:status], "must be active, inactive, suspended, or terminated"
  end

  test "should validate regulatory status" do
    valid_statuses = %w[authorized provisional suspended revoked]
    valid_statuses.each do |status|
      @psp.regulatory_status = status
      assert @psp.valid?, "#{status} should be valid"
    end

    @psp.regulatory_status = "invalid_status"
    assert_not @psp.valid?
    assert_includes @psp.errors[:regulatory_status], "must be authorized, provisional, suspended, or revoked"
  end

  test "should validate document type" do
    # Test CNPJ
    @psp.document_type = "CNPJ"
    @psp.document_number = "12345678000190"
    assert @psp.valid?, "CNPJ should be valid"

    # Test CPF
    @psp.document_type = "CPF"
    @psp.document_number = "12345678901"
    assert @psp.valid?, "CPF should be valid"

    @psp.document_type = "INVALID"
    assert_not @psp.valid?
    assert_includes @psp.errors[:document_type], "não está incluído na lista"
  end

  test "should validate numerical fields" do
    @psp.total_transactions = -1
    assert_not @psp.valid?
    assert_includes @psp.errors[:total_transactions], "deve ser maior ou igual a 0"

    @psp.total_transactions = 0
    @psp.total_volume = -100
    assert_not @psp.valid?
    assert_includes @psp.errors[:total_volume], "deve ser maior ou igual a 0"

    @psp.total_volume = 0
    @psp.availability_percentage = 101
    assert_not @psp.valid?
    assert_includes @psp.errors[:availability_percentage], "deve ser menor ou igual a 100"
  end

  test "should validate state format" do
    @psp.state = "SP"
    assert @psp.valid?

    @psp.state = "sp" # lowercase gets normalized to uppercase
    assert @psp.valid?
    assert_equal "SP", @psp.state

    @psp.state = "SAO" # 3 letters
    assert_not @psp.valid?
    assert_includes @psp.errors[:state], "não possui o tamanho esperado (2 caracteres)"
  end

  # Callback tests
  test "should normalize fields before validation" do
    @psp.ispb = " 12345678 "
    @psp.name = " Test Provider "
    @psp.document_number = "12.345.678/0001-99"
    @psp.state = "sp"
    @psp.contact_email = " TEST@EXAMPLE.COM "

    @psp.valid?

    assert_equal "12345678", @psp.ispb
    assert_equal "Test Provider", @psp.name
    assert_equal "12345678000199", @psp.document_number
    assert_equal "SP", @psp.state
    assert_equal "test@example.com", @psp.contact_email
  end

  test "should validate document number length based on type" do
    @psp.document_type = "CNPJ"
    @psp.document_number = "1234567800019" # 13 digits
    assert_not @psp.valid?
    assert_includes @psp.errors[:document_number], "deve ter 14 dígitos para CNPJ"

    @psp.document_type = "CPF"
    @psp.document_number = "1234567890" # 10 digits
    assert_not @psp.valid?
    assert_includes @psp.errors[:document_number], "deve ter 11 dígitos para CPF"

    @psp.document_type = "CPF"
    @psp.document_number = "12345678901" # 11 digits
    assert @psp.valid?
  end

  # Scope tests
  test "active scope should return only active PSPs" do
    active_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(status: "active"))
    inactive_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(status: "inactive"))

    active_psps = PaymentServiceProvider.active
    assert_includes active_psps, active_psp
    assert_not_includes active_psps, inactive_psp
  end

  test "pix_enabled scope should return only PIX-enabled PSPs" do
    pix_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(pix_enabled: true))
    non_pix_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(pix_enabled: false))

    pix_psps = PaymentServiceProvider.pix_enabled
    assert_includes pix_psps, pix_psp
    assert_not_includes pix_psps, non_pix_psp
  end

  test "needs_sync scope should return PSPs that need synchronization" do
    fresh_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(last_sync_at: 30.minutes.ago))
    stale_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(last_sync_at: 2.hours.ago))
    never_synced_psp = PaymentServiceProvider.create!(valid_psp_attributes.merge(last_sync_at: nil))

    stale_psps = PaymentServiceProvider.needs_sync
    assert_not_includes stale_psps, fresh_psp
    assert_includes stale_psps, stale_psp
    assert_includes stale_psps, never_synced_psp
  end

  # Instance method tests
  test "sync_status should return correct status" do
    # Never synced
    @psp.last_sync_at = nil
    assert_equal "never_synced", @psp.sync_status

    # Up to date
    @psp.last_sync_at = 30.minutes.ago
    @psp.last_successful_sync_at = 30.minutes.ago
    @psp.sync_attempts = 1
    assert_equal "up_to_date", @psp.sync_status

    # Needs sync
    @psp.last_sync_at = 2.hours.ago
    assert_equal "needs_sync", @psp.sync_status

    # Sync failed
    @psp.last_sync_at = 30.minutes.ago
    @psp.last_successful_sync_at = 2.hours.ago
    @psp.sync_attempts = 3
    assert_equal "sync_failed", @psp.sync_status
  end

  test "operational_status should return correct status" do
    # Operational - need good sync health
    @psp.status = "active"
    @psp.regulatory_status = "authorized"
    @psp.pix_enabled = true
    @psp.last_sync_at = 10.minutes.ago
    @psp.last_successful_sync_at = 10.minutes.ago
    @psp.sync_attempts = 1
    @psp.availability_percentage = 99.9
    @psp.error_count_24h = 0
    assert_equal "operational", @psp.operational_status

    # Inactive
    @psp.status = "inactive"
    assert_equal "inactive", @psp.operational_status

    # Unauthorized
    @psp.status = "active"
    @psp.regulatory_status = "suspended"
    assert_equal "unauthorized", @psp.operational_status

    # PIX disabled
    @psp.regulatory_status = "authorized"
    @psp.pix_enabled = false
    assert_equal "pix_disabled", @psp.operational_status
  end

  test "sync_health_score should calculate correctly" do
    # Never synced
    @psp.last_sync_at = nil
    assert_equal 0, @psp.sync_health_score

    # Sync failed
    @psp.last_sync_at = 1.hour.ago
    @psp.last_successful_sync_at = nil
    @psp.sync_attempts = 3
    assert_equal 25, @psp.sync_health_score

    # Good health
    @psp.last_sync_at = 30.minutes.ago
    @psp.last_successful_sync_at = 30.minutes.ago
    @psp.sync_attempts = 1
    @psp.availability_percentage = 99.9
    @psp.error_count_24h = 0
    assert @psp.sync_health_score >= 95
  end

  test "formatted_document should format correctly" do
    @psp.document_type = "CNPJ"
    @psp.document_number = "12345678000199"
    assert_equal "12.345.678/0001-99", @psp.formatted_document

    @psp.document_type = "CPF"
    @psp.document_number = "12345678901"
    assert_equal "123.456.789-01", @psp.formatted_document
  end

  test "pix_services should return only PIX-related services" do
    @psp.services_offered = [ "pix_payment", "ted_transfer", "pix_receiving", "doc_transfer" ]
    pix_services = @psp.pix_services

    assert_includes pix_services, "pix_payment"
    assert_includes pix_services, "pix_receiving"
    assert_not_includes pix_services, "ted_transfer"
    assert_not_includes pix_services, "doc_transfer"
  end

  test "display_name should prefer short_name when available" do
    @psp.short_name = "TestPSP"
    assert_equal "TestPSP", @psp.display_name

    @psp.short_name = nil
    assert_equal "Test Payment Provider", @psp.display_name
  end

  # ShortId functionality (inherited from concern)
  test "should include ShortId functionality" do
    @psp.save!
    assert_respond_to @psp, :short_id
    assert_respond_to @psp, :display_id
    assert @psp.short_id.present?
    assert @psp.display_id.present?
  end

  test "should find by short_id" do
    @psp.save!
    short_id = @psp.short_id

    found_psp = PaymentServiceProvider.find_by_any_id(short_id)
    assert_equal @psp, found_psp
  end

  # Class method tests
  test "pix_adoption_rate should calculate correctly" do
    initial_total = PaymentServiceProvider.count
    initial_pix_enabled = PaymentServiceProvider.pix_enabled.count

    PaymentServiceProvider.create!(valid_psp_attributes.merge(pix_enabled: true))
    PaymentServiceProvider.create!(valid_psp_attributes.merge(pix_enabled: false))

    # Should be (initial_pix_enabled + 1) / (initial_total + 2) * 100
    expected_rate = ((initial_pix_enabled + 1).to_f / (initial_total + 2) * 100).round(2)
    assert_equal expected_rate, PaymentServiceProvider.pix_adoption_rate
  end

  test "sync_health_summary should provide overview" do
    initial_total = PaymentServiceProvider.count
    initial_needs_sync = PaymentServiceProvider.needs_sync.count
    initial_sync_failed = PaymentServiceProvider.sync_failed.count

    PaymentServiceProvider.create!(valid_psp_attributes.merge(last_sync_at: 2.hours.ago))
    PaymentServiceProvider.create!(valid_psp_attributes.merge(last_sync_at: nil, sync_attempts: 3))

    summary = PaymentServiceProvider.sync_health_summary

    assert_equal initial_total + 2, summary[:total]
    assert_equal initial_needs_sync + 2, summary[:needs_sync]
    assert_equal initial_sync_failed + 1, summary[:sync_failed]
  end

  test "top_by_volume should return highest volume PSPs" do
    low_volume = PaymentServiceProvider.create!(valid_psp_attributes.merge(total_volume: 1000))
    high_volume = PaymentServiceProvider.create!(valid_psp_attributes.merge(total_volume: 10000))
    zero_volume = PaymentServiceProvider.create!(valid_psp_attributes.merge(total_volume: 0))

    top_psps = PaymentServiceProvider.top_by_volume(2)

    assert_equal [ high_volume, low_volume ], top_psps.to_a
    assert_not_includes top_psps, zero_volume
  end
end

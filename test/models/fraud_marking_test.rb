# frozen_string_literal: true

require "test_helper"

class FraudMarkingTest < ActiveSupport::TestCase
  setup do
    @fraud_marking = fraud_markings(:cpf_fraud)
  end

  test "should be valid with valid attributes" do
    fraud_marking = FraudMarking.new(
      pix_key: "12345678901",
      pix_key_type: "CPF",
      fraud_type: "account_takeover",
      evidence_description: "Suspicious activity detected",
      risk_score: 0.75,
      reported_by: "manual_review"
    )

    assert fraud_marking.valid?
  end

  test "should require pix_key" do
    @fraud_marking.pix_key = ""
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "não pode ficar em branco"
  end

  test "should require valid pix_key_type" do
    @fraud_marking.pix_key_type = "INVALID"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key_type], "não está incluído na lista"

    valid_types = %w[CPF CNPJ EMAIL PHONE UUID]
    valid_types.each do |type|
      @fraud_marking.pix_key_type = type
      assert @fraud_marking.valid?, "#{type} should be valid"
    end
  end

  test "should require valid fraud_type" do
    @fraud_marking.fraud_type = "invalid_type"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:fraud_type], "não está incluído na lista"

    valid_types = %w[account_takeover identity_theft social_engineering money_laundering other]
    valid_types.each do |type|
      @fraud_marking.fraud_type = type
      assert @fraud_marking.valid?, "#{type} should be valid"
    end
  end

  test "should require risk_score between 0 and 1" do
    @fraud_marking.risk_score = -0.1
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:risk_score], "deve ser maior ou igual a 0"

    @fraud_marking.risk_score = 1.1
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:risk_score], "deve ser menor ou igual a 1"

    @fraud_marking.risk_score = 0.5
    assert @fraud_marking.valid?
  end

  test "should validate CPF format when pix_key_type is CPF" do
    @fraud_marking.pix_key_type = "CPF"
    @fraud_marking.pix_key = "123"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "deve ter 11 dígitos"

    @fraud_marking.pix_key = "12345678901"
    assert @fraud_marking.valid?
  end

  test "should validate CNPJ format when pix_key_type is CNPJ" do
    @fraud_marking.pix_key_type = "CNPJ"
    @fraud_marking.pix_key = "123"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "deve ter 14 dígitos"

    @fraud_marking.pix_key = "12345678000195"
    assert @fraud_marking.valid?
  end

  test "should validate EMAIL format when pix_key_type is EMAIL" do
    @fraud_marking.pix_key_type = "EMAIL"
    @fraud_marking.pix_key = "invalid-email"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "deve ser um email válido"

    @fraud_marking.pix_key = "user@example.com"
    assert @fraud_marking.valid?
  end

  test "should validate PHONE format when pix_key_type is PHONE" do
    @fraud_marking.pix_key_type = "PHONE"
    @fraud_marking.pix_key = "123"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "deve estar no formato internacional"

    @fraud_marking.pix_key = "+5511999999999"
    assert @fraud_marking.valid?
  end

  test "should validate UUID format when pix_key_type is UUID" do
    @fraud_marking.pix_key_type = "UUID"
    @fraud_marking.pix_key = "invalid-uuid"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:pix_key], "deve ser um UUID válido"

    @fraud_marking.pix_key = "550e8400-e29b-41d4-a716-446655440000"
    assert @fraud_marking.valid?
  end

  test "should generate short_id on creation" do
    fraud_marking = FraudMarking.create!(
      pix_key: "98765432100",
      pix_key_type: "CPF",
      fraud_type: "account_takeover",
      evidence_description: "Test evidence",
      risk_score: 0.8,
      reported_by: "test"
    )

    assert fraud_marking.short_id.present?
    assert_match(/^FRM\d{3}$/, fraud_marking.short_id)
  end

  test "should have default status of pending" do
    fraud_marking = FraudMarking.new
    assert_equal "pending", fraud_marking.status
  end

  test "should validate status values" do
    valid_statuses = %w[pending submitted approved rejected failed]
    valid_statuses.each do |status|
      @fraud_marking.status = status
      assert @fraud_marking.valid?, "#{status} should be valid"
    end

    @fraud_marking.status = "invalid_status"
    assert_not @fraud_marking.valid?
    assert_includes @fraud_marking.errors[:status], "não está incluído na lista"
  end

  test "should scope by status" do
    pending_markings = FraudMarking.pending
    assert_includes pending_markings, @fraud_marking

    @fraud_marking.update!(status: "submitted")
    pending_markings = FraudMarking.pending
    assert_not_includes pending_markings, @fraud_marking

    submitted_markings = FraudMarking.submitted
    assert_includes submitted_markings, @fraud_marking
  end

  test "should scope by pix_key_type" do
    cpf_markings = FraudMarking.with_pix_key_type("CPF")
    assert_includes cpf_markings, @fraud_marking

    email_markings = FraudMarking.with_pix_key_type("EMAIL")
    assert_not_includes email_markings, @fraud_marking
  end

  test "should scope by fraud_type" do
    account_takeover_markings = FraudMarking.with_fraud_type("account_takeover")
    assert_includes account_takeover_markings, @fraud_marking

    identity_theft_markings = FraudMarking.with_fraud_type("identity_theft")
    assert_not_includes identity_theft_markings, @fraud_marking
  end

  test "should return status in Portuguese" do
    status_translations = {
      "pending" => "Pendente",
      "submitted" => "Submetido",
      "approved" => "Aprovado",
      "rejected" => "Rejeitado",
      "failed" => "Falhou",
    }

    status_translations.each do |status, expected_translation|
      @fraud_marking.status = status
      assert_equal expected_translation, @fraud_marking.status_in_portuguese
    end
  end

  test "should return fraud_type in Portuguese" do
    type_translations = {
      "account_takeover" => "Tomada de conta",
      "identity_theft" => "Roubo de identidade",
      "social_engineering" => "Engenharia social",
      "money_laundering" => "Lavagem de dinheiro",
      "other" => "Outro",
    }

    type_translations.each do |type, expected_translation|
      @fraud_marking.fraud_type = type
      assert_equal expected_translation, @fraud_marking.fraud_type_in_portuguese
    end
  end

  test "should format risk score as percentage" do
    @fraud_marking.risk_score = 0.857
    assert_equal "85.7%", @fraud_marking.risk_score_percentage
  end

  test "should mask PIX key for display" do
    # CPF masking
    @fraud_marking.pix_key_type = "CPF"
    @fraud_marking.pix_key = "12345678901"
    assert_equal "123.***.***-01", @fraud_marking.masked_pix_key

    # Email masking
    @fraud_marking.pix_key_type = "EMAIL"
    @fraud_marking.pix_key = "user@example.com"
    assert_equal "u***@example.com", @fraud_marking.masked_pix_key

    # Phone masking
    @fraud_marking.pix_key_type = "PHONE"
    @fraud_marking.pix_key = "+5511999999999"
    assert_equal "+55119****9999", @fraud_marking.masked_pix_key
  end

  test "should check if submittable" do
    @fraud_marking.status = "pending"
    assert @fraud_marking.submittable?

    @fraud_marking.status = "failed"
    assert @fraud_marking.submittable?

    @fraud_marking.status = "submitted"
    assert_not @fraud_marking.submittable?
  end

  test "should initialize arrays for jdpi_response_data and submission_errors" do
    fraud_marking = FraudMarking.new
    assert_equal({}, fraud_marking.jdpi_response_data)
    assert_equal [], fraud_marking.submission_errors
  end
end

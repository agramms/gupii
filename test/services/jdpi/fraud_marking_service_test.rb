# frozen_string_literal: true

require "test_helper"

class Jdpi::FraudMarkingServiceTest < ActiveSupport::TestCase
  setup do
    @service = Jdpi::FraudMarkingService.new
    @fraud_marking = fraud_markings(:cpf_fraud)
  end

  test "should submit fraud marking successfully" do
    # Mock successful API response
    mock_response = {
      "protocolo" => "JDPI-2024-001234",
      "status" => "ACEITO",
      "dataHora" => "2024-01-15T10:30:00Z"
    }

    @service.expects(:post).with("/jdpi/fraud-markings", anything)
           .returns(mock_response)

    result = @service.submit_fraud_marking(@fraud_marking)

    assert result[:success]
    assert_equal "JDPI-2024-001234", result[:protocol]
    assert_equal "ACEITO", result[:status]
  end

  test "should handle JDPI rejection" do
    # Mock rejection response
    mock_response = {
      "erro" => {
        "codigo" => "EVIDENCE_INSUFFICIENT",
        "mensagem" => "Evidência insuficiente para marcação de fraude"
      }
    }

    @service.expects(:post).with("/jdpi/fraud-markings", anything)
           .returns(mock_response)

    result = @service.submit_fraud_marking(@fraud_marking)

    assert_not result[:success]
    assert_equal "EVIDENCE_INSUFFICIENT", result[:error_code]
    assert_match "insuficiente", result[:error_message]
  end

  test "should handle network errors" do
    @service.expects(:post).with("/jdpi/fraud-markings", anything)
           .raises(Net::TimeoutError.new("Request timeout"))

    result = @service.submit_fraud_marking(@fraud_marking)

    assert_not result[:success]
    assert_equal "NETWORK_ERROR", result[:error_code]
    assert_match "timeout", result[:error_message]
  end

  test "should build correct request payload" do
    expected_payload = {
      "chave_pix" => @fraud_marking.pix_key,
      "tipo_chave" => @fraud_marking.pix_key_type,
      "tipo_fraude" => @fraud_marking.fraud_type,
      "descricao_evidencia" => @fraud_marking.evidence_description,
      "score_risco" => @fraud_marking.risk_score,
      "reportado_por" => @fraud_marking.reported_by,
      "data_ocorrencia" => @fraud_marking.created_at.iso8601
    }

    actual_payload = @service.send(:build_request_payload, @fraud_marking)

    assert_equal expected_payload, actual_payload
  end

  test "should validate fraud marking before submission" do
    invalid_fraud_marking = FraudMarking.new(
      pix_key: "",
      pix_key_type: "INVALID",
      fraud_type: "",
      risk_score: 1.5
    )

    result = @service.submit_fraud_marking(invalid_fraud_marking)

    assert_not result[:success]
    assert_equal "VALIDATION_ERROR", result[:error_code]
    assert_match "inválidos", result[:error_message]
  end

  test "should handle authentication failure" do
    # Mock authentication service failure
    Jdpi::AuthenticationService.any_instance.expects(:get_access_token)
                              .raises(Jdpi::AuthenticationService::AuthenticationError.new("Token expired"))

    result = @service.submit_fraud_marking(@fraud_marking)

    assert_not result[:success]
    assert_equal "AUTHENTICATION_ERROR", result[:error_code]
    assert_match "autenticação", result[:error_message]
  end

  test "should retry on transient failures" do
    # Mock transient failure followed by success
    mock_response = {
      "protocolo" => "JDPI-2024-001234",
      "status" => "ACEITO"
    }

    @service.expects(:post).with("/jdpi/fraud-markings", anything)
           .raises(Net::HTTPServerError.new("Internal server error"))
           .then.returns(mock_response)

    result = @service.submit_fraud_marking(@fraud_marking)

    assert result[:success]
    assert_equal "JDPI-2024-001234", result[:protocol]
  end

  test "should update fraud marking status after successful submission" do
    mock_response = {
      "protocolo" => "JDPI-2024-001234",
      "status" => "ACEITO"
    }

    @service.expects(:post).returns(mock_response)

    @service.submit_fraud_marking(@fraud_marking)

    @fraud_marking.reload
    assert_equal "submitted", @fraud_marking.status
    assert @fraud_marking.jdpi_response_data.present?
    assert_equal "JDPI-2024-001234", @fraud_marking.jdpi_response_data["protocolo"]
  end

  test "should log submission errors" do
    @service.expects(:post).raises(StandardError.new("API Error"))

    @service.submit_fraud_marking(@fraud_marking)

    @fraud_marking.reload
    assert @fraud_marking.submission_errors.present?
    assert_match "API Error", @fraud_marking.submission_errors.first
  end
end
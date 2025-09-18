# frozen_string_literal: true

require "test_helper"

class FraudMarkingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fraud_marking = fraud_markings(:cpf_fraud)
  end

  test "should get index" do
    get fraud_markings_path

    assert_response :success
    assert_match "Marcações de Fraude", response.body
  end

  test "should show fraud marking" do
    get fraud_marking_path(@fraud_marking)

    assert_response :success
    assert_match @fraud_marking.short_id, response.body
    assert_match @fraud_marking.pix_key, response.body
  end

  test "should get new fraud marking" do
    get new_fraud_marking_path

    assert_response :success
    assert_match "Nova Marcação", response.body
  end

  test "should create fraud marking" do
    assert_difference("FraudMarking.count") do
      post fraud_markings_path, params: {
        fraud_marking: {
          pix_key: "98765432100",
          pix_key_type: "CPF",
          fraud_type: "account_takeover",
          evidence_description: "Suspicious activity detected",
          risk_score: 0.75,
          reported_by: "manual_review"
        }
      }
    end

    assert_redirected_to fraud_marking_path(FraudMarking.last)
  end

  test "should not create fraud marking with invalid params" do
    assert_no_difference("FraudMarking.count") do
      post fraud_markings_path, params: {
        fraud_marking: {
          pix_key: "",
          pix_key_type: "INVALID",
          fraud_type: "",
          risk_score: 1.5
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "erro", response.body.downcase
  end

  test "should get edit fraud marking" do
    get edit_fraud_marking_path(@fraud_marking)

    assert_response :success
    assert_match "Editar", response.body
  end

  test "should update fraud marking" do
    patch fraud_marking_path(@fraud_marking), params: {
      fraud_marking: {
        evidence_description: "Updated evidence description",
        risk_score: 0.90
      }
    }

    assert_redirected_to fraud_marking_path(@fraud_marking)
    @fraud_marking.reload
    assert_equal "Updated evidence description", @fraud_marking.evidence_description
    assert_equal 0.90, @fraud_marking.risk_score
  end

  test "should not update fraud marking with invalid params" do
    patch fraud_marking_path(@fraud_marking), params: {
      fraud_marking: {
        pix_key: "",
        risk_score: 2.0
      }
    }

    assert_response :unprocessable_entity
    assert_match "erro", response.body.downcase
  end

  test "should submit fraud marking to JDPI" do
    # Mock the JDPI service
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).returns({
      success: true,
      protocol: "JDPI-2024-TEST123"
    })

    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    patch submit_fraud_marking_path(@fraud_marking)

    assert_redirected_to fraud_marking_path(@fraud_marking)
    assert_match "submetida com sucesso", flash[:notice]
  end

  test "should handle JDPI submission failure" do
    # Mock the JDPI service to return failure
    service_mock = mock
    service_mock.expects(:submit_fraud_marking).returns({
      success: false,
      error: "JDPI service unavailable"
    })

    Jdpi::FraudMarkingService.expects(:new).returns(service_mock)

    patch submit_fraud_marking_path(@fraud_marking)

    assert_redirected_to fraud_marking_path(@fraud_marking)
    assert_match "Erro ao submeter", flash[:alert]
  end

  test "should destroy fraud marking" do
    assert_difference("FraudMarking.count", -1) do
      delete fraud_marking_path(@fraud_marking)
    end

    assert_redirected_to fraud_markings_path
  end

  test "should export fraud markings" do
    get export_fraud_markings_path, params: { format: :csv }

    assert_response :success
    assert_equal "text/csv", response.content_type
    assert_match "attachment", response.headers["Content-Disposition"]
  end

  test "should filter fraud markings by status" do
    get fraud_markings_path, params: { status: "pending" }

    assert_response :success
    assert_match "pending", response.body
  end

  test "should filter fraud markings by pix key type" do
    get fraud_markings_path, params: { pix_key_type: "CPF" }

    assert_response :success
    assert_match "CPF", response.body
  end
end
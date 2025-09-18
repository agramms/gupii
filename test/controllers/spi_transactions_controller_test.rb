# frozen_string_literal: true

require "test_helper"

class SpiTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @valid_e2e_id = "E12345678901234567890123456789012"
    @invalid_e2e_id = "INVALID123"
  end

  test "should get index page" do
    get spi_transactions_path

    assert_response :success
    assert_match "Consulta SPI", response.body
    assert_match "End-to-End ID", response.body
  end

  test "should show lookup form" do
    get spi_transactions_path

    assert_response :success
    assert_select "form[action=?]", spi_transactions_path
    assert_select "input[name=?]", "end_to_end_id"
    assert_select "input[type=submit]"
  end

  test "should validate end-to-end ID format" do
    post spi_transactions_path, params: {
      end_to_end_id: @invalid_e2e_id,
    }

    assert_response :unprocessable_content
    assert_match "deve ter exatamente 32 caracteres", response.body
  end

  test "should handle successful SPI transaction lookup" do
    # Mock successful SPI service response
    service_mock = mock
    service_mock.expects(:lookup_transaction).with(@valid_e2e_id).returns({
      success: true,
      transaction: {
        end_to_end_id: @valid_e2e_id,
        status: "COMPLETED",
        amount: 100.50,
        currency: "BRL",
        payer_institution: "12345678",
        payee_institution: "87654321",
        created_at: "2024-01-15T10:30:00Z",
      },
    })

    Jdpi::SpiTransactionService.expects(:new).returns(service_mock)

    post spi_transactions_path, params: {
      end_to_end_id: @valid_e2e_id,
    }

    assert_response :success
    assert_match @valid_e2e_id, response.body
    assert_match "COMPLETED", response.body
    assert_match "100,50", response.body
  end

  test "should handle transaction not found" do
    # Mock service response for not found
    service_mock = mock
    service_mock.expects(:lookup_transaction).with(@valid_e2e_id).returns({
      success: false,
      error: "TRANSACTION_NOT_FOUND",
      message: "Transaction not found in SPI",
    })

    Jdpi::SpiTransactionService.expects(:new).returns(service_mock)

    post spi_transactions_path, params: {
      end_to_end_id: @valid_e2e_id,
    }

    assert_response :unprocessable_content
    assert_match "Transação não encontrada", response.body
  end

  test "should handle JDPI service error" do
    # Mock service response for API error
    service_mock = mock
    service_mock.expects(:lookup_transaction).with(@valid_e2e_id).returns({
      success: false,
      error: "API_ERROR",
      message: "JDPI service temporarily unavailable",
    })

    Jdpi::SpiTransactionService.expects(:new).returns(service_mock)

    post spi_transactions_path, params: {
      end_to_end_id: @valid_e2e_id,
    }

    assert_response :unprocessable_content
    assert_match "Erro na consulta", response.body
  end

  test "should handle service exception" do
    # Mock service to raise exception
    Jdpi::SpiTransactionService.expects(:new).raises(StandardError.new("Connection timeout"))

    post spi_transactions_path, params: {
      end_to_end_id: @valid_e2e_id,
    }

    assert_response :unprocessable_content
    assert_match "Erro interno", response.body
  end

  test "should require end_to_end_id parameter" do
    post spi_transactions_path, params: {}

    assert_response :unprocessable_content
    assert_match "End-to-End ID é obrigatório", response.body
  end

  test "should trim whitespace from end_to_end_id" do
    service_mock = mock
    service_mock.expects(:lookup_transaction).with(@valid_e2e_id).returns({
      success: true,
      transaction: { end_to_end_id: @valid_e2e_id },
    })

    Jdpi::SpiTransactionService.expects(:new).returns(service_mock)

    post spi_transactions_path, params: {
      end_to_end_id: "  #{@valid_e2e_id}  ",
    }

    assert_response :success
  end

  test "should display help information" do
    get spi_transactions_path

    assert_response :success
    assert_match "Como usar", response.body
    assert_match "32 caracteres", response.body
    assert_match "exemplo", response.body
  end
end

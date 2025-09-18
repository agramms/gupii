# frozen_string_literal: true

require "test_helper"

class Jdpi::SpiTransactionServiceTest < ActiveSupport::TestCase
  setup do
    @service = Jdpi::SpiTransactionService.new
    @valid_e2e_id = "E12345678901234567890123456789012"
  end

  test "should lookup transaction successfully" do
    # Mock successful API response
    mock_response_data = {
      "endToEndId" => @valid_e2e_id,
      "status" => "COMPLETED",
      "valorLancamento" => 100.50,
      "moeda" => "BRL",
      "ispbPsp" => "12345678",
      "ispbRecebedor" => "87654321",
      "dataHoraLancamento" => "2024-01-15T10:30:00Z",
      "tipoLancamento" => "CREDIT",
      "formaPagamento" => "PIX"
    }

    @service.expects(:get).with("/jdpi/spi/api/v2/lancamento/#{@valid_e2e_id}")
           .returns(mock_response_data)

    result = @service.lookup_transaction(@valid_e2e_id)

    assert result[:success]
    assert_equal @valid_e2e_id, result[:transaction][:end_to_end_id]
    assert_equal "COMPLETED", result[:transaction][:status]
    assert_equal 100.50, result[:transaction][:amount]
    assert_equal "BRL", result[:transaction][:currency]
  end

  test "should handle transaction not found" do
    @service.expects(:get).with("/jdpi/spi/api/v2/lancamento/#{@valid_e2e_id}")
           .raises(Jdpi::SpiTransactionService::TransactionNotFoundError.new("Transaction not found"))

    result = @service.lookup_transaction(@valid_e2e_id)

    assert_not result[:success]
    assert_equal "TRANSACTION_NOT_FOUND", result[:error]
    assert_match "não encontrada", result[:message]
  end

  test "should handle invalid format error" do
    invalid_e2e_id = "INVALID123"

    @service.expects(:get).with("/jdpi/spi/api/v2/lancamento/#{invalid_e2e_id}")
           .raises(Jdpi::SpiTransactionService::InvalidFormatError.new("Invalid format"))

    result = @service.lookup_transaction(invalid_e2e_id)

    assert_not result[:success]
    assert_equal "INVALID_FORMAT", result[:error]
    assert_match "formato inválido", result[:message]
  end

  test "should handle API error" do
    @service.expects(:get).with("/jdpi/spi/api/v2/lancamento/#{@valid_e2e_id}")
           .raises(Jdpi::SpiTransactionService::ApiError.new("API temporarily unavailable"))

    result = @service.lookup_transaction(@valid_e2e_id)

    assert_not result[:success]
    assert_equal "API_ERROR", result[:error]
    assert_match "temporariamente indisponível", result[:message]
  end

  test "should handle general exceptions" do
    @service.expects(:get).with("/jdpi/spi/api/v2/lancamento/#{@valid_e2e_id}")
           .raises(StandardError.new("Network timeout"))

    result = @service.lookup_transaction(@valid_e2e_id)

    assert_not result[:success]
    assert_equal "UNKNOWN_ERROR", result[:error]
    assert_match "Erro inesperado", result[:message]
  end

  test "should normalize transaction data correctly" do
    raw_data = {
      "endToEndId" => @valid_e2e_id,
      "status" => "PENDING",
      "valorLancamento" => 250.75,
      "moeda" => "BRL",
      "ispbPsp" => "11111111",
      "ispbRecebedor" => "22222222",
      "dataHoraLancamento" => "2024-02-20T15:45:30Z",
      "tipoLancamento" => "DEBIT",
      "formaPagamento" => "TED",
      "descricaoLancamento" => "Test payment"
    }

    normalized = @service.send(:normalize_transaction_data, raw_data)

    assert_equal @valid_e2e_id, normalized[:end_to_end_id]
    assert_equal "PENDING", normalized[:status]
    assert_equal 250.75, normalized[:amount]
    assert_equal "BRL", normalized[:currency]
    assert_equal "11111111", normalized[:payer_institution]
    assert_equal "22222222", normalized[:payee_institution]
    assert_equal "2024-02-20T15:45:30Z", normalized[:created_at]
    assert_equal "DEBIT", normalized[:transaction_type]
    assert_equal "TED", normalized[:payment_method]
    assert_equal "Test payment", normalized[:description]
  end

  test "should handle missing optional fields in normalization" do
    minimal_data = {
      "endToEndId" => @valid_e2e_id,
      "status" => "COMPLETED"
    }

    normalized = @service.send(:normalize_transaction_data, minimal_data)

    assert_equal @valid_e2e_id, normalized[:end_to_end_id]
    assert_equal "COMPLETED", normalized[:status]
    assert_nil normalized[:amount]
    assert_nil normalized[:description]
  end

  test "should validate end-to-end ID format" do
    assert_raises(Jdpi::SpiTransactionService::InvalidFormatError) do
      @service.send(:validate_end_to_end_id!, "SHORT")
    end

    assert_raises(Jdpi::SpiTransactionService::InvalidFormatError) do
      @service.send(:validate_end_to_end_id!, "TOO_LONG_E2E_ID_THAT_EXCEEDS_LIMIT_123")
    end

    assert_raises(Jdpi::SpiTransactionService::InvalidFormatError) do
      @service.send(:validate_end_to_end_id!, "")
    end

    assert_raises(Jdpi::SpiTransactionService::InvalidFormatError) do
      @service.send(:validate_end_to_end_id!, nil)
    end

    # Should not raise for valid ID
    assert_nothing_raised do
      @service.send(:validate_end_to_end_id!, @valid_e2e_id)
    end
  end
end
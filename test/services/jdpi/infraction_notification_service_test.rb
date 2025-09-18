# frozen_string_literal: true

require "test_helper"

class Jdpi::InfractionNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @service = Jdpi::InfractionNotificationService.new
    @infraction = infraction_notifications(:fraud_notification)
  end

  test "should fetch infraction notifications successfully" do
    # Mock successful API response
    mock_response = {
      "notificacoes" => [
        {
          "id" => "INF-001",
          "chave_pix" => "12345678901",
          "tipo_infracao" => "FRAUDE",
          "descricao" => "Atividade suspeita detectada",
          "data_ocorrencia" => "2024-01-15T10:30:00Z",
          "status" => "PENDENTE",
        },
        {
          "id" => "INF-002",
          "chave_pix" => "test@example.com",
          "tipo_infracao" => "LAVAGEM_DINHEIRO",
          "descricao" => "Transações em valor elevado",
          "data_ocorrencia" => "2024-01-14T15:20:00Z",
          "status" => "PROCESSADO",
        },
      ],
      "total" => 2,
      "pagina" => 1,
    }

    @service.expects(:get).with("/jdpi/infraction-notifications", anything)
           .returns(mock_response)

    result = @service.fetch_notifications

    assert result[:success]
    assert_equal 2, result[:notifications].count
    assert_equal "INF-001", result[:notifications].first[:id]
    assert_equal "FRAUDE", result[:notifications].first[:infraction_type]
  end

  test "should handle empty notifications response" do
    mock_response = {
      "notificacoes" => [],
      "total" => 0,
      "pagina" => 1,
    }

    @service.expects(:get).returns(mock_response)

    result = @service.fetch_notifications

    assert result[:success]
    assert_empty result[:notifications]
    assert_equal 0, result[:total]
  end

  test "should acknowledge notification successfully" do
    mock_response = {
      "protocolo" => "ACK-2024-001234",
      "status" => "CONFIRMADO",
      "data_confirmacao" => "2024-01-15T11:00:00Z",
    }

    @service.expects(:post).with("/jdpi/infraction-notifications/#{@infraction.external_id}/acknowledge", anything)
           .returns(mock_response)

    result = @service.acknowledge_notification(@infraction)

    assert result[:success]
    assert_equal "ACK-2024-001234", result[:protocol]
    assert_equal "CONFIRMADO", result[:status]
  end

  test "should handle acknowledgment failure" do
    mock_response = {
      "erro" => {
        "codigo" => "NOTIFICATION_NOT_FOUND",
        "mensagem" => "Notificação não encontrada",
      },
    }

    @service.expects(:post).returns(mock_response)

    result = @service.acknowledge_notification(@infraction)

    assert_not result[:success]
    assert_equal "NOTIFICATION_NOT_FOUND", result[:error_code]
    assert_match "não encontrada", result[:error_message]
  end

  test "should normalize notification data correctly" do
    raw_data = {
      "id" => "INF-123",
      "chave_pix" => "user@example.com",
      "tipo_infracao" => "FRAUDE",
      "descricao" => "Suspicious activity",
      "data_ocorrencia" => "2024-01-15T10:30:00Z",
      "status" => "PENDENTE",
      "instituicao_reportante" => "12345678",
      "evidencias" => [ "documento1.pdf", "log_transacao.txt" ],
    }

    normalized = @service.send(:normalize_notification_data, raw_data)

    assert_equal "INF-123", normalized[:external_id]
    assert_equal "user@example.com", normalized[:pix_key]
    assert_equal "FRAUDE", normalized[:infraction_type]
    assert_equal "Suspicious activity", normalized[:description]
    assert_equal "2024-01-15T10:30:00Z", normalized[:occurred_at]
    assert_equal "PENDENTE", normalized[:status]
    assert_equal "12345678", normalized[:reporting_institution]
    assert_equal [ "documento1.pdf", "log_transacao.txt" ], normalized[:evidence_files]
  end

  test "should fetch notifications with pagination" do
    mock_response = {
      "notificacoes" => [],
      "total" => 50,
      "pagina" => 2,
      "total_paginas" => 5,
    }

    expected_params = {
      page: 2,
      per_page: 10,
      status: "PENDENTE",
    }

    @service.expects(:get).with("/jdpi/infraction-notifications", expected_params)
           .returns(mock_response)

    result = @service.fetch_notifications(page: 2, per_page: 10, status: "PENDENTE")

    assert result[:success]
    assert_equal 50, result[:total]
    assert_equal 2, result[:page]
    assert_equal 5, result[:total_pages]
  end

  test "should handle API authentication errors" do
    @service.expects(:get).raises(Net::HTTPUnauthorized.new("Invalid token", nil))

    result = @service.fetch_notifications

    assert_not result[:success]
    assert_equal "AUTHENTICATION_ERROR", result[:error_code]
    assert_match "autenticação", result[:error_message]
  end

  test "should handle API rate limiting" do
    @service.expects(:get).raises(Net::HTTPTooManyRequests.new("Rate limit exceeded", nil))

    result = @service.fetch_notifications

    assert_not result[:success]
    assert_equal "RATE_LIMIT_ERROR", result[:error_code]
    assert_match "muitas requisições", result[:error_message]
  end

  test "should validate infraction before acknowledgment" do
    invalid_infraction = InfractionNotification.new(external_id: nil)

    result = @service.acknowledge_notification(invalid_infraction)

    assert_not result[:success]
    assert_equal "VALIDATION_ERROR", result[:error_code]
    assert_match "inválida", result[:error_message]
  end

  test "should update infraction status after successful acknowledgment" do
    mock_response = {
      "protocolo" => "ACK-2024-001234",
      "status" => "CONFIRMADO",
    }

    @service.expects(:post).returns(mock_response)

    @service.acknowledge_notification(@infraction)

    @infraction.reload
    assert_equal "acknowledged", @infraction.status
    assert @infraction.jdpi_metadata.present?
    assert_equal "ACK-2024-001234", @infraction.jdpi_metadata["acknowledgment_protocol"]
  end
end

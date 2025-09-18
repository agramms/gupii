# frozen_string_literal: true

require "test_helper"

class DisputeTest < ActiveSupport::TestCase
  setup do
    @dispute = disputes(:pending_dispute)
    @infraction = infraction_notifications(:fraud_notification)
  end

  test "should be valid with valid attributes" do
    dispute = Dispute.new(
      infraction_notification: @infraction,
      requester_name: "Test User",
      requester_email: "test@example.com",
      requester_phone: "+5511999999999",
      dispute_reason: "Transaction not authorized",
      evidence_description: "I was not at the location",
      timeline_days: 7
    )

    assert dispute.valid?
  end

  test "should require infraction notification" do
    @dispute.infraction_notification = nil
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:infraction_notification], "é obrigatório(a)"
  end

  test "should require requester name" do
    @dispute.requester_name = ""
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:requester_name], "não pode ficar em branco"
  end

  test "should require valid email format" do
    @dispute.requester_email = "invalid-email"
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:requester_email], "não é válido"
  end

  test "should require valid phone format" do
    @dispute.requester_phone = "123"
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:requester_phone], "deve estar no formato internacional"
  end

  test "should require timeline days between 1 and 14" do
    @dispute.timeline_days = 0
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:timeline_days], "deve ser maior que 0"

    @dispute.timeline_days = 15
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:timeline_days], "deve ser menor ou igual a 14"
  end

  test "should generate short_id on creation" do
    dispute = Dispute.create!(
      infraction_notification: @infraction,
      requester_name: "Test User",
      requester_email: "test@example.com",
      requester_phone: "+5511999999999",
      dispute_reason: "Test reason",
      evidence_description: "Test evidence",
      timeline_days: 7
    )

    assert dispute.short_id.present?
    assert_match(/^DSP\d{3}$/, dispute.short_id)
  end

  test "should set customer response deadline on creation" do
    dispute = Dispute.create!(
      infraction_notification: @infraction,
      requester_name: "Test User",
      requester_email: "test@example.com",
      requester_phone: "+5511999999999",
      dispute_reason: "Test reason",
      evidence_description: "Test evidence",
      timeline_days: 7
    )

    expected_deadline = 6.days.from_now.to_date
    assert_equal expected_deadline, dispute.customer_response_deadline.to_date
  end

  test "should have default status of pending_customer_response" do
    dispute = Dispute.new
    assert_equal "pending_customer_response", dispute.status
  end

  test "should validate status transitions" do
    # Valid transition: pending_customer_response -> under_internal_review
    @dispute.status = "under_internal_review"
    assert @dispute.valid?

    # Invalid transition: approved -> pending_customer_response
    @dispute.status = "approved"
    @dispute.save!
    @dispute.status = "pending_customer_response"
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:status], "transição inválida"
  end

  test "should check if overdue" do
    # Not overdue
    @dispute.customer_response_deadline = 1.day.from_now
    assert_not @dispute.overdue?

    # Overdue
    @dispute.customer_response_deadline = 1.day.ago
    assert @dispute.overdue?
  end

  test "should scope overdue disputes" do
    # Create overdue dispute
    overdue_dispute = Dispute.create!(
      infraction_notification: @infraction,
      requester_name: "Overdue User",
      requester_email: "overdue@example.com",
      requester_phone: "+5511888888888",
      dispute_reason: "Test reason",
      evidence_description: "Test evidence",
      timeline_days: 7,
      customer_response_deadline: 1.day.ago
    )

    overdue_disputes = Dispute.overdue
    assert_includes overdue_disputes, overdue_dispute
    assert_not_includes overdue_disputes, @dispute
  end

  test "should scope pending disputes" do
    pending_disputes = Dispute.pending_customer_response
    assert_includes pending_disputes, @dispute

    @dispute.update!(status: "approved")
    pending_disputes = Dispute.pending_customer_response
    assert_not_includes pending_disputes, @dispute
  end

  test "should validate resolution notes for final statuses" do
    @dispute.status = "approved"
    @dispute.resolution_notes = nil
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:resolution_notes], "são obrigatórias"

    @dispute.resolution_notes = "Dispute approved based on evidence"
    assert @dispute.valid?
  end

  test "should not allow duplicate disputes for same infraction" do
    duplicate_dispute = Dispute.new(
      infraction_notification: @dispute.infraction_notification,
      requester_name: "Another User",
      requester_email: "another@example.com",
      requester_phone: "+5511777777777",
      dispute_reason: "Different reason",
      evidence_description: "Different evidence",
      timeline_days: 5
    )

    assert_not duplicate_dispute.valid?
    assert_includes duplicate_dispute.errors[:infraction_notification], "já possui uma disputa"
  end

  test "should format phone number for display" do
    @dispute.requester_phone = "+5511999999999"
    assert_equal "(11) 99999-9999", @dispute.formatted_phone
  end

  test "should return status in Portuguese" do
    status_translations = {
      "pending_customer_response" => "Aguardando resposta do cliente",
      "under_internal_review" => "Em análise interna",
      "pending_resolution" => "Aguardando resolução",
      "approved" => "Aprovada",
      "rejected" => "Rejeitada",
      "escalated" => "Escalada",
      "auto_declined" => "Recusada automaticamente"
    }

    status_translations.each do |status, expected_translation|
      @dispute.status = status
      assert_equal expected_translation, @dispute.status_in_portuguese
    end
  end

  test "should calculate days until deadline" do
    @dispute.customer_response_deadline = 3.days.from_now
    assert_equal 3, @dispute.days_until_deadline

    @dispute.customer_response_deadline = 1.day.ago
    assert_equal(-1, @dispute.days_until_deadline)
  end
end
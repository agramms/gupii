# frozen_string_literal: true

require "test_helper"

class DisputeTest < ActiveSupport::TestCase
  setup do
    @dispute = disputes(:pending_dispute)
    @infraction = infraction_notifications(:fraud_notification)
  end

  test "should be valid with valid attributes" do
    # Use a different infraction that doesn't have a dispute yet
    other_infraction = infraction_notifications(:aml_notification)
    dispute = Dispute.new(
      infraction_notification: other_infraction,
      justification: "Transaction not authorized by customer",
      evidence_notes: "Customer was not at the location during transaction",
      created_by: "customer_service",
      customer_response_due_at: 7.days.from_now
    )

    unless dispute.valid?
      puts "Validation errors: #{dispute.errors.full_messages}"
    end
    assert dispute.valid?
  end

  test "should require infraction notification" do
    @dispute.infraction_notification = nil
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:infraction_notification], "é obrigatório(a)"
  end

  test "should require created_by" do
    @dispute.created_by = ""
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:created_by], "não pode ficar em branco"
  end

  test "should require justification" do
    @dispute.justification = ""
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:justification], "não pode ficar em branco"
  end

  test "should require customer_response_due_at" do
    @dispute.customer_response_due_at = nil
    assert_not @dispute.valid?
    assert_includes @dispute.errors[:customer_response_due_at], "não pode ficar em branco"
  end

  test "should generate short_id on creation" do
    dispute = Dispute.create!(
      infraction_notification: @infraction,
      created_by: "Test User",
      justification: "Test reason",
      evidence_notes: "Test evidence",
      customer_response_due_at: 7.days.from_now
    )

    assert dispute.short_id.present?
    assert_match(/^DSP\d{3}$/, dispute.short_id)
  end

  test "should set customer response deadline on creation" do
    dispute = Dispute.create!(
      infraction_notification: @infraction,
      created_by: "Test User",
      justification: "Test reason",
      evidence_notes: "Test evidence",
      customer_response_due_at: 7.days.from_now
    )

    expected_deadline = 6.days.from_now.to_date
    assert_equal expected_deadline, dispute.customer_response_due_at.to_date
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
    assert_includes @dispute.errors[:status], "cannot transition"
  end

  test "should check if overdue" do
    # Not overdue
    @dispute.customer_response_due_at = 1.day.from_now
    assert_not @dispute.overdue?

    # Overdue
    @dispute.customer_response_due_at = 1.day.ago
    assert @dispute.overdue?
  end

  test "should scope overdue disputes" do
    # Create overdue dispute
    overdue_dispute = Dispute.create!(
      infraction_notification: @infraction,
      created_by: "Overdue User",
      evidence_notes: "overdue@example.com",
      additional_data: "+5511888888888",
      justification: "Test reason",
      evidence_notes: "Test evidence",
      customer_response_due_at: 7,
      customer_response_due_at: 1.day.ago
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
      created_by: "Another User",
      evidence_notes: "another@example.com",
      additional_data: "+5511777777777",
      justification: "Different reason",
      evidence_notes: "Different evidence",
      customer_response_due_at: 5
    )

    assert_not duplicate_dispute.valid?
    assert_includes duplicate_dispute.errors[:infraction_notification], "já possui uma disputa"
  end

  test "should handle additional data" do
    @dispute.additional_data = { "phone" => "+5511999999999", "documents" => ["id", "proof"] }
    assert @dispute.valid?
    assert_equal "+5511999999999", @dispute.additional_data["phone"]
  end

  test "should return status in Portuguese" do
    status_translations = {
      "pending_customer_response" => "Aguardando resposta do cliente",
      "under_internal_review" => "Em análise interna",
      "pending_resolution" => "Aguardando resolução",
      "approved" => "Aprovada",
      "rejected" => "Rejeitada",
      "escalated" => "Escalada",
      "auto_declined" => "Recusada automaticamente",
    }

    status_translations.each do |status, expected_translation|
      @dispute.status = status
      assert_equal expected_translation, @dispute.status_in_portuguese
    end
  end

  test "should calculate days until deadline" do
    @dispute.customer_response_due_at = 3.days.from_now
    assert_equal 3, @dispute.days_until_deadline

    @dispute.customer_response_due_at = 1.day.ago
    assert_equal(-1, @dispute.days_until_deadline)
  end
end

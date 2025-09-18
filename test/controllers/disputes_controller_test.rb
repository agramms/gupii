# frozen_string_literal: true

require "test_helper"

class DisputesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dispute = disputes(:pending_dispute)
    @infraction_notification = infraction_notifications(:fraud_notification)
  end

  test "should get index" do
    get disputes_path

    assert_response :success
    assert_match "Disputas", response.body
  end

  test "should show dispute" do
    get dispute_path(@dispute)

    assert_response :success
    assert_match @dispute.short_id, response.body
  end

  test "should get new dispute for infraction notification" do
    get new_infraction_notification_dispute_path(@infraction_notification)

    assert_response :success
    assert_match "Nova Disputa", response.body
  end

  test "should create dispute" do
    assert_difference("Dispute.count") do
      post infraction_notification_disputes_path(@infraction_notification), params: {
        dispute: {
          requester_name: "Test User",
          requester_email: "test@example.com",
          requester_phone: "+5511999999999",
          dispute_reason: "Transaction not authorized",
          evidence_description: "I was not at the location",
          timeline_days: 7,
        },
      }
    end

    assert_redirected_to dispute_path(Dispute.last)
  end

  test "should not create dispute with invalid params" do
    assert_no_difference("Dispute.count") do
      post infraction_notification_disputes_path(@infraction_notification), params: {
        dispute: {
          requester_name: "",
          requester_email: "invalid-email",
          timeline_days: 0,
        },
      }
    end

    assert_response :unprocessable_content
    assert_match "erro", response.body.downcase
  end

  test "should approve dispute" do
    patch approve_dispute_path(@dispute), params: {
      resolution_notes: "Evidence confirmed the dispute",
    }

    assert_redirected_to dispute_path(@dispute)
    @dispute.reload
    assert_equal "approved", @dispute.status
    assert_equal "Evidence confirmed the dispute", @dispute.resolution_notes
  end

  test "should reject dispute" do
    patch reject_dispute_path(@dispute), params: {
      resolution_notes: "Insufficient evidence provided",
    }

    assert_redirected_to dispute_path(@dispute)
    @dispute.reload
    assert_equal "rejected", @dispute.status
    assert_equal "Insufficient evidence provided", @dispute.resolution_notes
  end

  test "should escalate dispute" do
    @dispute.update!(status: "under_internal_review")

    patch escalate_dispute_path(@dispute), params: {
      escalation_notes: "Requires senior review",
    }

    assert_redirected_to dispute_path(@dispute)
    @dispute.reload
    assert_equal "escalated", @dispute.status
  end

  test "should decline overdue dispute" do
    @dispute.update!(
      status: "pending_customer_response",
      customer_response_deadline: 1.day.ago
    )

    patch decline_dispute_path(@dispute)

    assert_redirected_to dispute_path(@dispute)
    @dispute.reload
    assert_equal "auto_declined", @dispute.status
  end

  test "should not approve dispute without resolution notes" do
    patch approve_dispute_path(@dispute)

    assert_response :unprocessable_content
    assert_match "obrigatórias", response.body.downcase
  end

  test "should not perform action on dispute in wrong status" do
    @dispute.update!(status: "approved")

    patch approve_dispute_path(@dispute), params: {
      resolution_notes: "Already approved",
    }

    assert_response :unprocessable_content
    assert_match "inválida", response.body.downcase
  end
end

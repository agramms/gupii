# frozen_string_literal: true

require "test_helper"

class FraudMarkingLogTest < ActiveSupport::TestCase
  setup do
    @fraud_marking = fraud_markings(:cpf_fraud)
    @log = fraud_marking_logs(:initial_submission)
  end

  test "should be valid with valid attributes" do
    log = FraudMarkingLog.new(
      fraud_marking: @fraud_marking,
      action: "reviewed",
      status_from: "pending",
      status_to: "approved",
      details: { reviewer: "analyst_001" },
      performed_by: "analyst_001"
    )

    assert log.valid?
  end

  test "should require fraud_marking" do
    @log.fraud_marking = nil
    assert_not @log.valid?
    assert_includes @log.errors[:fraud_marking], "é obrigatório(a)"
  end

  test "should require action" do
    @log.action = ""
    assert_not @log.valid?
    assert_includes @log.errors[:action], "não pode ficar em branco"
  end

  test "should require performed_by" do
    @log.performed_by = ""
    assert_not @log.valid?
    assert_includes @log.errors[:performed_by], "não pode ficar em branco"
  end

  test "should validate action values" do
    valid_actions = %w[created submitted reviewed approved rejected resubmitted]
    valid_actions.each do |action|
      @log.action = action
      assert @log.valid?, "#{action} should be valid"
    end

    @log.action = "invalid_action"
    assert_not @log.valid?
    assert_includes @log.errors[:action], "não está incluído na lista"
  end

  test "should initialize details as empty hash by default" do
    log = FraudMarkingLog.new
    assert_equal({}, log.details)
  end

  test "should store details as JSON" do
    details = {
      reviewer: "analyst_001",
      review_duration_minutes: 45,
      notes: "Evidence is sufficient"
    }

    @log.details = details
    @log.save!
    @log.reload

    assert_equal details.stringify_keys, @log.details
  end

  test "should scope by fraud_marking" do
    other_fraud_marking = fraud_markings(:email_fraud_submitted)
    other_log = FraudMarkingLog.create!(
      fraud_marking: other_fraud_marking,
      action: "created",
      performed_by: "system"
    )

    logs_for_cpf_fraud = FraudMarkingLog.for_fraud_marking(@fraud_marking)
    assert_includes logs_for_cpf_fraud, @log
    assert_not_includes logs_for_cpf_fraud, other_log
  end

  test "should scope by action" do
    submission_logs = FraudMarkingLog.with_action("submitted")
    assert_includes submission_logs, @log

    review_logs = FraudMarkingLog.with_action("reviewed")
    assert_not_includes review_logs, @log
  end

  test "should order by created_at descending by default" do
    newer_log = FraudMarkingLog.create!(
      fraud_marking: @fraud_marking,
      action: "reviewed",
      performed_by: "analyst",
      created_at: 1.hour.from_now
    )

    logs = FraudMarkingLog.for_fraud_marking(@fraud_marking)
    assert_equal newer_log, logs.first
  end

  test "should return action in Portuguese" do
    action_translations = {
      "created" => "Criado",
      "submitted" => "Submetido",
      "reviewed" => "Revisado",
      "approved" => "Aprovado",
      "rejected" => "Rejeitado",
      "resubmitted" => "Reenviado"
    }

    action_translations.each do |action, expected_translation|
      @log.action = action
      assert_equal expected_translation, @log.action_in_portuguese
    end
  end

  test "should format status transition" do
    @log.status_from = "pending"
    @log.status_to = "submitted"
    assert_equal "pending → submitted", @log.status_transition
  end

  test "should handle nil status_from in transition" do
    @log.status_from = nil
    @log.status_to = "pending"
    assert_equal "— → pending", @log.status_transition
  end

  test "should handle nil status_to in transition" do
    @log.status_from = "pending"
    @log.status_to = nil
    assert_equal "pending → —", @log.status_transition
  end

  test "should extract performer type from performed_by" do
    system_performers = ["system", "automated_system", "jdpi_system"]
    system_performers.each do |performer|
      @log.performed_by = performer
      assert_equal "system", @log.performer_type
    end

    @log.performed_by = "analyst_001"
    assert_equal "user", @log.performer_type

    @log.performed_by = "admin@example.com"
    assert_equal "user", @log.performer_type
  end

  test "should check if performed by system" do
    @log.performed_by = "automated_system"
    assert @log.system_performed?

    @log.performed_by = "analyst_001"
    assert_not @log.system_performed?
  end

  test "should summarize details for display" do
    @log.details = {
      "reviewer" => "analyst_001",
      "review_duration_minutes" => 45,
      "evidence_quality" => "sufficient",
      "recommendation" => "approve"
    }

    summary = @log.details_summary
    assert_includes summary, "reviewer: analyst_001"
    assert_includes summary, "review_duration_minutes: 45"
    assert_includes summary, "evidence_quality: sufficient"
  end

  test "should handle empty details in summary" do
    @log.details = {}
    assert_equal "—", @log.details_summary
  end

  test "should create log entry with factory method" do
    log = FraudMarkingLog.log_action(
      fraud_marking: @fraud_marking,
      action: "approved",
      status_from: "pending",
      status_to: "approved",
      performed_by: "analyst_001",
      details: { reason: "Evidence confirmed" }
    )

    assert log.persisted?
    assert_equal "approved", log.action
    assert_equal @fraud_marking, log.fraud_marking
    assert_equal "analyst_001", log.performed_by
    assert_equal({ "reason" => "Evidence confirmed" }, log.details)
  end
end
# frozen_string_literal: true

# Dispute Model
# Handles internal dispute process for infraction notifications
# Business Rule: Customer has 6 days to respond (7 - 1), or dispute is auto-declined
class Dispute < ApplicationRecord
  include ShortId

  # Associations
  belongs_to :infraction_notification

  # Enums
  enum :dispute_type, {
    validity_challenge: 0,
    insufficient_evidence: 1,
    procedural_error: 2,
    escalation_required: 3,
    technical_issue: 4,
  }, prefix: true

  enum :status, {
    pending_customer_response: 0,
    under_internal_review: 1,
    pending_resolution: 2,
    approved: 3,
    rejected: 4,
    auto_declined: 5,
    escalated: 6,
  }, prefix: true

  # Validations
  validates :justification, presence: true, length: { maximum: 2000 }
  validates :created_by, presence: true
  validates :customer_response_due_at, presence: true
  validates :dispute_type, presence: true
  validates :status, presence: true

  validate :ensure_unique_per_infraction
  validate :validate_timeline_constraints
  validate :validate_status_transitions

  # Scopes
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_dispute_type, ->(type) { where(dispute_type: type) if type.present? }
  scope :by_created_by, ->(creator) { where(created_by: creator) if creator.present? }
  scope :overdue_customer_response, -> {
    where(status: :pending_customer_response)
    .where("customer_response_due_at < ?", Time.current)
  }
  scope :approaching_deadline, -> {
    where(status: :pending_customer_response)
    .where("customer_response_due_at BETWEEN ? AND ?", Time.current, 24.hours.from_now)
  }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where.not(status: [ :approved, :rejected, :auto_declined ]) }

  # Callbacks
  before_validation :set_customer_response_deadline, on: :create
  before_create :set_default_values
  after_update :log_status_change, if: :saved_change_to_status?
  after_update :update_infraction_dispute_status

  # Constants
  CUSTOMER_RESPONSE_DAYS = 6 # 7 days - 1 day = 6 days for customer response

  # Instance Methods

  def days_until_deadline
    return 0 if customer_response_due_at.nil? || customer_response_due_at < Time.current
    ((customer_response_due_at - Time.current) / 1.day).ceil
  end

  def hours_until_deadline
    return 0 if customer_response_due_at.nil? || customer_response_due_at < Time.current
    ((customer_response_due_at - Time.current) / 1.hour).ceil
  end

  def overdue_for_customer_response?
    status_pending_customer_response? && customer_response_due_at < Time.current
  end

  def approaching_deadline?
    status_pending_customer_response? &&
      customer_response_due_at > Time.current &&
      customer_response_due_at <= 24.hours.from_now
  end

  def can_auto_decline?
    status_pending_customer_response? && overdue_for_customer_response?
  end

  def auto_decline!
    return false unless can_auto_decline?

    transaction do
      update!(
        status: :auto_declined,
        resolved_at: Time.current,
        resolution_notes: "Automatically declined - no customer response within #{CUSTOMER_RESPONSE_DAYS} days",
        final_decision: "auto_declined"
      )

      # Update infraction notification status
      infraction_notification.update!(dispute_status: "auto_declined")

      # Log the auto-decline
      create_status_log("auto_declined", "system", "Auto-declined due to no customer response")
    end

    true
  end

  def approve_dispute!(reviewer:, resolution_notes:, next_actions: nil)
    return false unless can_approve?

    transaction do
      update!(
        status: :approved,
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        resolved_at: Time.current,
        resolution_notes: resolution_notes,
        next_actions: next_actions,
        final_decision: "approved"
      )

      infraction_notification.update!(dispute_status: "approved")
      create_status_log("approved", reviewer, resolution_notes)
    end

    true
  end

  def reject_dispute!(reviewer:, resolution_notes:, next_actions: nil)
    return false unless can_reject?

    transaction do
      update!(
        status: :rejected,
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        resolved_at: Time.current,
        resolution_notes: resolution_notes,
        next_actions: next_actions,
        final_decision: "rejected"
      )

      infraction_notification.update!(dispute_status: "rejected")
      create_status_log("rejected", reviewer, resolution_notes)
    end

    true
  end

  def escalate!(escalated_by:, escalation_reason:, assigned_to: nil)
    return false unless can_escalate?

    transaction do
      update!(
        status: :escalated,
        assigned_to: assigned_to,
        reviewed_by: escalated_by,
        reviewed_at: Time.current,
        resolution_notes: escalation_reason,
        final_decision: "escalated"
      )

      infraction_notification.update!(dispute_status: "escalated")
      create_status_log("escalated", escalated_by, escalation_reason)
    end

    true
  end

  def assign_reviewer!(assignee:, assigned_by:)
    return false if resolved?

    update!(
      assigned_to: assignee,
      status: :under_internal_review
    )

    create_status_log("assigned", assigned_by, "Assigned to #{assignee}")
    true
  end

  def resolved?
    status.in?(%w[approved rejected auto_declined])
  end

  def can_approve?
    status.in?(%w[under_internal_review pending_resolution])
  end

  def can_reject?
    status.in?(%w[under_internal_review pending_resolution])
  end

  def can_escalate?
    !resolved? && !status_escalated?
  end

  def can_be_cancelled?
    status_pending_customer_response? || status_under_internal_review?
  end

  def timeline_summary
    {
      created: created_at,
      submitted: submitted_at,
      customer_response_due: customer_response_due_at,
      days_remaining: days_until_deadline,
      reviewed: reviewed_at,
      resolved: resolved_at,
      is_overdue: overdue_for_customer_response?,
      is_approaching_deadline: approaching_deadline?,
    }
  end

  # Class Methods

  def self.auto_decline_overdue!
    overdue_count = 0

    overdue_customer_response.find_each do |dispute|
      if dispute.auto_decline!
        overdue_count += 1
        Rails.logger.info "[Dispute] Auto-declined dispute #{dispute.id} for infraction #{dispute.infraction_notification.id}"
      end
    end

    Rails.logger.info "[Dispute] Auto-declined #{overdue_count} overdue disputes" if overdue_count > 0
    overdue_count
  end

  def self.approaching_deadlines_summary
    approaching_deadline.group(:dispute_type).count
  end

  def self.overdue_summary
    overdue_customer_response.group(:dispute_type).count
  end

  private

  def set_customer_response_deadline
    return if customer_response_due_at.present?

    # Customer has 6 days from dispute creation to respond (7 - 1)
    self.customer_response_due_at = CUSTOMER_RESPONSE_DAYS.days.from_now
  end

  def set_default_values
    self.submitted_at ||= Time.current
    self.additional_data ||= {}
  end

  def ensure_unique_per_infraction
    return unless infraction_notification_id.present?

    existing = Dispute.where(infraction_notification_id: infraction_notification_id)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:infraction_notification_id, "can only have one dispute per infraction notification")
    end
  end

  def validate_timeline_constraints
    return unless customer_response_due_at.present?

    if customer_response_due_at <= Time.current
      errors.add(:customer_response_due_at, "must be in the future")
    end

    # Ensure customer response deadline is reasonable (between 1 and 14 days)
    days_from_now = (customer_response_due_at - Time.current) / 1.day
    unless days_from_now.between?(1, 14)
      errors.add(:customer_response_due_at, "must be between 1 and 14 days from now")
    end
  end

  def validate_status_transitions
    return unless status_changed?

    old_status = status_was&.to_s
    new_status = status.to_s

    valid_transitions = {
      "pending_customer_response" => %w[under_internal_review auto_declined],
      "under_internal_review" => %w[pending_resolution approved rejected escalated],
      "pending_resolution" => %w[approved rejected escalated],
      "escalated" => %w[approved rejected],
    }

    if old_status && !valid_transitions[old_status]&.include?(new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  def log_status_change
    create_status_log(status, reviewed_by || created_by, "Status changed to #{status}")
  end

  def create_status_log(status, actor, notes)
    # Could create a DisputeLog model similar to InfractionLog
    Rails.logger.info "[Dispute] #{infraction_notification.id} - Status: #{status} by #{actor} - #{notes}"
  end

  def update_infraction_dispute_status
    case status.to_s
    when "pending_customer_response"
      infraction_notification.update!(dispute_status: "pending")
    when "under_internal_review", "pending_resolution"
      infraction_notification.update!(dispute_status: "under_review")
    when "approved"
      infraction_notification.update!(dispute_status: "approved")
    when "rejected", "auto_declined"
      infraction_notification.update!(dispute_status: "rejected")
    when "escalated"
      infraction_notification.update!(dispute_status: "escalated")
    end
  end
end

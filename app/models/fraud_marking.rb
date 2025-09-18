# frozen_string_literal: true

# Fraud Marking Model
# Tracks PIX fraud markings submitted to JDPI for fraudulent key reporting
# Maintains local state, approval workflows, and audit trail for compliance
# Domain model - JDPI-specific logic is handled in Jdpi::FraudMarkingService
class FraudMarking < ApplicationRecord
  include Jdpi::StatusCodes
  include ShortId

  # Constants for fraud types (based on JDPI API documentation)
  module FraudTypes
    ACCOUNT_TAKEOVER = "ACCOUNT_TAKEOVER".freeze
    SIM_SWAP = "SIM_SWAP".freeze
    PHISHING = "PHISHING".freeze
    SOCIAL_ENGINEERING = "SOCIAL_ENGINEERING".freeze
    IDENTITY_THEFT = "IDENTITY_THEFT".freeze
    FAKE_REGISTRATION = "FAKE_REGISTRATION".freeze
    SUSPICIOUS_TRANSACTION = "SUSPICIOUS_TRANSACTION".freeze
    MONEY_LAUNDERING = "MONEY_LAUNDERING".freeze
    OTHER_FRAUD = "OTHER_FRAUD".freeze

    ALL = [
      ACCOUNT_TAKEOVER,
      SIM_SWAP,
      PHISHING,
      SOCIAL_ENGINEERING,
      IDENTITY_THEFT,
      FAKE_REGISTRATION,
      SUSPICIOUS_TRANSACTION,
      MONEY_LAUNDERING,
      OTHER_FRAUD,
    ].freeze
  end

  # Status constants aligned with JDPI API
  module Status
    PENDING = "PENDING".freeze
    SUBMITTED = "SUBMITTED".freeze
    PROCESSING = "PROCESSING".freeze
    ACTIVE = "ACTIVE".freeze
    CANCELLED = "CANCELLED".freeze
    REJECTED = "REJECTED".freeze
    EXPIRED = "EXPIRED".freeze
    SUPERSEDED = "SUPERSEDED".freeze
    ERROR = "ERROR".freeze

    ALL = [
      PENDING,
      SUBMITTED,
      PROCESSING,
      ACTIVE,
      CANCELLED,
      REJECTED,
      EXPIRED,
      SUPERSEDED,
      ERROR,
    ].freeze

    PENDING_STATES = [ PENDING, SUBMITTED, PROCESSING ].freeze
    FINAL_STATES = [ ACTIVE, CANCELLED, REJECTED, EXPIRED, SUPERSEDED ].freeze
  end

  # Risk levels for classification
  module RiskLevel
    LOW = "LOW".freeze
    MEDIUM = "MEDIUM".freeze
    HIGH = "HIGH".freeze
    CRITICAL = "CRITICAL".freeze

    ALL = [ LOW, MEDIUM, HIGH, CRITICAL ].freeze
  end

  # Sources for fraud marking creation
  module Sources
    CUSTOMER_SERVICE = "CUSTOMER_SERVICE".freeze
    FRAUD_TEAM = "FRAUD_TEAM".freeze
    COMPLIANCE_TEAM = "COMPLIANCE_TEAM".freeze
    AUTOMATED_SYSTEM = "AUTOMATED_SYSTEM".freeze
    EXTERNAL_REPORT = "EXTERNAL_REPORT".freeze

    ALL = [ CUSTOMER_SERVICE, FRAUD_TEAM, COMPLIANCE_TEAM, AUTOMATED_SYSTEM, EXTERNAL_REPORT ].freeze
  end

  # Classification levels
  module Classification
    CONFIRMED_FRAUD = "CONFIRMED_FRAUD".freeze
    SUSPECTED_FRAUD = "SUSPECTED_FRAUD".freeze
    INVESTIGATION_REQUIRED = "INVESTIGATION_REQUIRED".freeze

    ALL = [ CONFIRMED_FRAUD, SUSPECTED_FRAUD, INVESTIGATION_REQUIRED ].freeze
  end

  # Validations
  validates :pix_key, presence: true, length: { maximum: 77 }
  validates :pix_key_type, presence: true, inclusion: { in: %w[CPF CNPJ EMAIL PHONE UUID] }
  validates :fraud_type, presence: true, inclusion: { in: FraudTypes::ALL }
  validates :classification, presence: true, inclusion: { in: Classification::ALL }
  validates :status, presence: true, inclusion: { in: Status::ALL }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :requested_by, presence: true
  validates :created_by_source, presence: true, inclusion: { in: Sources::ALL }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :risk_level, inclusion: { in: RiskLevel::ALL }, allow_blank: true
  validates :risk_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true
  validates :transaction_amount, numericality: { greater_than: 0 }, allow_blank: true
  validates :transaction_currency, inclusion: { in: %w[BRL USD EUR] }, allow_blank: true
  validates :jdpi_marking_id, uniqueness: true, allow_nil: true
  validates :days_remaining_to_respond, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  validate :validate_pix_key_format
  validate :validate_status_transitions
  validate :validate_evidence_data_structure
  validate :validate_approval_requirements
  validate :validate_cancellation_requirements

  # Scopes
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_fraud_type, ->(type) { where(fraud_type: type) if type.present? }
  scope :by_pix_key, ->(key) { where(pix_key: key) if key.present? }
  scope :by_classification, ->(classification) { where(classification: classification) if classification.present? }
  scope :by_risk_level, ->(level) { where(risk_level: level) if level.present? }
  scope :by_requested_by, ->(user) { where(requested_by: user) if user.present? }
  scope :by_source, ->(source) { where(created_by_source: source) if source.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_approval, -> { where(status: Status::PENDING) }
  scope :submitted, -> { where(status: Status::SUBMITTED) }
  scope :active, -> { where(status: Status::ACTIVE) }
  scope :pending_states, -> { where(status: Status::PENDING_STATES) }
  scope :final_states, -> { where(status: Status::FINAL_STATES) }
  scope :high_risk, -> { where(risk_level: [ RiskLevel::HIGH, RiskLevel::CRITICAL ]) }
  scope :requires_approval, -> { where(requires_supervisor_approval: true) }
  scope :sensitive_cases, -> { where(sensitive_case: true) }
  scope :overdue, -> { where("response_due_at < ? AND status IN (?)", Time.current, Status::PENDING_STATES) }
  scope :created_after, ->(date) { where("created_at >= ?", date) if date.present? }
  scope :created_before, ->(date) { where("created_at <= ?", date) if date.present? }

  # Callbacks
  before_validation :normalize_data, on: :create
  before_create :set_default_values
  before_save :update_days_remaining
  after_update :log_status_change, if: :saved_change_to_status?

  # Associations
  has_many :fraud_marking_logs, dependent: :destroy
  has_many_attached :evidence_files

  # Instance Methods

  def pix_key_type_enum
    Jdpi::StatusCodes::Utils.detect_pix_key_type(pix_key)
  end

  def masked_pix_key_display
    self.masked_pix_key || Jdpi::StatusCodes::Utils.mask_sensitive_data(pix_key, :pix_key)
  end

  def fraud_type_description
    I18n.t("fraud_markings.dropdown_options.fraud_types.#{fraud_type.downcase}", default: fraud_type.humanize)
  end

  def classification_description
    I18n.t("fraud_markings.dropdown_options.classifications.#{classification.downcase}", default: classification.humanize)
  end

  def status_description
    I18n.t("fraud_markings.dropdown_options.statuses.#{status.downcase}", default: status.humanize)
  end

  def source_description
    I18n.t("fraud_markings.dropdown_options.sources.#{created_by_source.downcase}", default: created_by_source.humanize)
  end

  def risk_level_description
    return "N/A" if risk_level.blank?
    I18n.t("fraud_markings.dropdown_options.risk_levels.#{risk_level.downcase}", default: risk_level.humanize)
  end

  # Status checking methods
  def pending?
    status == Status::PENDING
  end

  def submitted?
    status == Status::SUBMITTED
  end

  def processing?
    status == Status::PROCESSING
  end

  def active?
    status == Status::ACTIVE
  end

  def cancelled?
    status == Status::CANCELLED
  end

  def rejected?
    status == Status::REJECTED
  end

  def expired?
    status == Status::EXPIRED
  end

  def final_state?
    Status::FINAL_STATES.include?(status)
  end

  def pending_state?
    Status::PENDING_STATES.include?(status)
  end

  # Business logic methods
  def can_be_submitted?
    pending? && approved?
  end

  def can_be_cancelled?
    pending_state? && !expired?
  end

  def can_be_approved?
    pending? && !approved?
  end

  def can_be_rejected?
    pending? && !approved?
  end

  def approved?
    approved_by.present? && approved_at.present?
  end

  def requires_approval?
    requires_supervisor_approval?
  end

  def high_priority?
    risk_level.in?([ RiskLevel::HIGH, RiskLevel::CRITICAL ]) ||
    sensitive_case? ||
    [ FraudTypes::ACCOUNT_TAKEOVER, FraudTypes::SIM_SWAP ].include?(fraud_type) ||
    (transaction_amount.present? && transaction_amount > 50000)
  end

  def overdue_for_response?
    response_due_at.present? && response_due_at < Time.current && pending_state?
  end

  def days_until_deadline
    return 0 unless response_due_at
    return 0 if response_due_at < Time.current
    ((response_due_at - Time.current) / 1.day).ceil
  end

  def deadline_urgency_class
    days_left = days_until_deadline
    return "deadline-expired" if overdue_for_response?
    return "deadline-critical" if days_left <= 1
    return "deadline-urgent" if days_left <= 2
    return "deadline-warning" if days_left <= 3
    "deadline-normal"
  end

  def priority_level
    return "critical" if risk_level == RiskLevel::CRITICAL
    return "high" if high_priority?
    return "medium" if risk_level == RiskLevel::MEDIUM
    "standard"
  end

  # Action methods
  def approve!(approved_by_user, notes: nil)
    raise ArgumentError, "Cannot approve: not in pending status" unless can_be_approved?

    update!(
      approved_by: approved_by_user,
      approved_at: Time.current,
      internal_notes: [ internal_notes, notes ].compact.join("\n\n")
    )

    log_action("approved", approved_by_user, { notes: notes })
    self
  end

  def reject!(rejected_by_user, reason:)
    raise ArgumentError, "Cannot reject: not in pending status" unless can_be_rejected?
    raise ArgumentError, "Rejection reason is required" if reason.blank?

    update!(
      status: Status::REJECTED,
      rejection_reason: reason,
      status_changed_at: Time.current
    )

    log_action("rejected", rejected_by_user, { reason: reason })
    self
  end

  def cancel!(cancelled_by_user, reason: nil)
    raise ArgumentError, "Cannot cancel: invalid status" unless can_be_cancelled?

    update!(
      status: Status::CANCELLED,
      cancelled_by: cancelled_by_user,
      cancelled_at: Time.current,
      cancellation_reason: reason,
      status_changed_at: Time.current
    )

    log_action("cancelled", cancelled_by_user, { reason: reason })
    self
  end

  def submit_to_jdpi!
    raise ArgumentError, "Cannot submit: not approved" unless can_be_submitted?

    update!(
      status: Status::SUBMITTED,
      submitted_at: Time.current,
      status_changed_at: Time.current
    )

    log_action("submitted_to_jdpi", requested_by)
    self
  end

  def update_status!(new_status, notes: nil, updated_by: nil)
    unless valid_status_transition?(status, new_status)
      raise ArgumentError, "Invalid status transition from #{status} to #{new_status}"
    end

    update!(
      status: new_status,
      status_changed_at: Time.current,
      internal_notes: [ internal_notes, notes ].compact.join("\n\n")
    )

    log_action("status_updated", updated_by || "system", {
      old_status: status_was,
      new_status: new_status,
      notes: notes,
    })
    self
  end

  # Update marking with external JDPI response
  def update_from_jdpi_response!(response_data)
    attributes_to_update = {}

    if response_data["markingId"].present?
      attributes_to_update[:jdpi_marking_id] = response_data["markingId"]
    end

    if response_data["status"].present?
      attributes_to_update[:status] = response_data["status"]
      attributes_to_update[:status_changed_at] = Time.current
    end

    if response_data["processedAt"].present?
      attributes_to_update[:processed_at] = Time.parse(response_data["processedAt"])
    end

    update!(attributes_to_update) if attributes_to_update.any?
  end

  # Class Methods

  def self.create_from_request!(pix_key:, fraud_type:, description:, requested_by:, **additional_attrs)
    create!(
      pix_key: pix_key,
      pix_key_type: Jdpi::StatusCodes::Utils.detect_pix_key_type(pix_key),
      fraud_type: fraud_type.to_s.upcase,
      description: description,
      requested_by: requested_by,
      status: Status::PENDING,
      idempotency_key: SecureRandom.uuid,
      **additional_attrs
    )
  end

  def self.find_by_jdpi_id(jdpi_marking_id)
    find_by(jdpi_marking_id: jdpi_marking_id)
  end

  def self.statistics
    {
      total: count,
      by_status: group(:status).count,
      by_fraud_type: group(:fraud_type).count,
      by_risk_level: group(:risk_level).count,
      pending_approval: where(status: Status::PENDING).count,
      active: where(status: Status::ACTIVE).count,
      overdue: overdue.count,
      high_priority: high_risk.count,
    }
  end

  private

  def normalize_data
    self.pix_key = pix_key&.strip
    self.fraud_type = fraud_type&.strip&.upcase
    self.classification = classification&.strip&.upcase
    self.description = description&.strip
    self.pix_key_type = Jdpi::StatusCodes::Utils.detect_pix_key_type(pix_key)&.upcase if pix_key.present?
    self.masked_pix_key = Jdpi::StatusCodes::Utils.mask_sensitive_data(pix_key, :pix_key) if pix_key.present?
  end

  def set_default_values
    self.status ||= Status::PENDING
    self.idempotency_key ||= SecureRandom.uuid
    self.response_due_at ||= 30.days.from_now # Default JDPI deadline
    self.days_remaining_to_respond ||= 30
    self.transaction_currency ||= "BRL"
    self.requires_supervisor_approval = true if requires_supervisor_approval.nil?
  end

  def update_days_remaining
    if response_due_at.present?
      self.days_remaining_to_respond = days_until_deadline
    end
  end

  def validate_pix_key_format
    return if pix_key.blank?

    unless Jdpi::StatusCodes::Utils.valid_pix_key?(pix_key)
      errors.add(:pix_key, "has invalid format for any supported PIX key type")
    end
  end

  def validate_status_transitions
    return unless status_changed? && persisted?

    old_status = status_was
    new_status = status

    unless valid_status_transition?(old_status, new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  def validate_evidence_data_structure
    return if evidence_data.blank?

    unless evidence_data.is_a?(Hash)
      errors.add(:evidence_data, "must be a valid JSON object")
      return
    end

    if evidence_data.to_json.bytesize > 64.kilobytes
      errors.add(:evidence_data, "cannot exceed 64KB in size")
    end
  end

  def validate_approval_requirements
    if requires_supervisor_approval? && status_changed? && status == Status::SUBMITTED
      unless approved?
        errors.add(:status, "cannot be submitted without supervisor approval")
      end
    end
  end

  def validate_cancellation_requirements
    if status == Status::CANCELLED
      if cancelled_by.blank?
        errors.add(:cancelled_by, "is required when status is cancelled")
      end

      if cancelled_at.blank?
        errors.add(:cancelled_at, "is required when status is cancelled")
      end
    end
  end

  def valid_status_transition?(from_status, to_status)
    return true if from_status == to_status

    valid_transitions = {
      Status::PENDING => [ Status::SUBMITTED, Status::REJECTED, Status::CANCELLED ],
      Status::SUBMITTED => [ Status::PROCESSING, Status::REJECTED, Status::CANCELLED ],
      Status::PROCESSING => [ Status::ACTIVE, Status::REJECTED, Status::ERROR ],
      Status::ACTIVE => [ Status::CANCELLED, Status::SUPERSEDED ],
      Status::ERROR => [ Status::SUBMITTED, Status::CANCELLED ],
    }

    valid_transitions[from_status]&.include?(to_status) || false
  end

  def log_status_change
    Rails.logger.info "[FraudMarking] Status changed for #{id}: #{status_was} → #{status}"
    log_action("status_changed", "system", {
      old_status: status_was,
      new_status: status,
    })
  end

  def log_action(action, user, metadata = {})
    FraudMarkingLog.create!(
      fraud_marking: self,
      level: "info",
      action: action,
      user: user,
      message: "#{action.humanize} by #{user}",
      metadata: metadata.merge(
        action_at: Time.current,
        fraud_marking_id: id
      )
    )
  end
end

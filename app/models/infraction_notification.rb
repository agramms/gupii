# frozen_string_literal: true

# Infraction Notification Model
# Tracks infraction notifications submitted to JDPI for PIX key violations
# Maintains local state and audit trail for compliance purposes
# Domain model - JDPI-specific logic is handled in Jdpi::InfractionNotificationService
class InfractionNotification < ApplicationRecord
  include Jdpi::StatusCodes
  include ShortId

  # Enums
  enum :dispute_status, {
    none: 0,
    pending: 1,
    under_review: 2,
    approved: 3,
    rejected: 4,
    auto_declined: 5,
    escalated: 6,
  }, prefix: true, default: :none

  # Validations
  validates :pix_key, presence: true, length: { maximum: 77 }
  validates :infraction_type, presence: true, inclusion: { in: InfractionTypes::ALL }
  validates :description, presence: true, length: { maximum: BusinessRules::MAX_DESCRIPTION_LENGTH }
  validates :status, presence: true, inclusion: { in: InfractionStatus::ALL }
  validates :created_by, presence: true, inclusion: { in: InfractionSources::ALL }
  validates :jdpi_notification_id, uniqueness: true, allow_nil: true
  validates :idempotency_key, presence: true, uniqueness: true

  validate :validate_pix_key_format
  validate :validate_status_transitions
  validate :validate_evidence_data_structure

  # Scopes
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_infraction_type, ->(type) { where(infraction_type: type) if type.present? }
  scope :by_pix_key, ->(key) { where(pix_key: key) if key.present? }
  scope :by_created_by, ->(source) { where(created_by: source) if source.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :submitted_after, ->(date) { where("submitted_at >= ?", date) if date.present? }
  scope :submitted_before, ->(date) { where("submitted_at <= ?", date) if date.present? }
  scope :pending, -> { where(status: [ InfractionStatus::SUBMITTED, InfractionStatus::PROCESSING ]) }
  scope :completed, -> { where(status: [ InfractionStatus::COMPLETED, InfractionStatus::CANCELLED ]) }
  scope :customer_service, -> { where(created_by: InfractionSources::CUSTOMER_SERVICE) }
  scope :customer_experience, -> { where(created_by: InfractionSources::CUSTOMER_EXPERIENCE) }
  scope :dict_automatic, -> { where(created_by: InfractionSources::DICT_AUTOMATIC) }

  # Callbacks
  before_validation :normalize_data, on: :create
  before_create :set_default_values
  before_save :update_days_remaining
  after_update :log_status_change, if: :saved_change_to_status?

  # Associations
  has_many :infraction_logs, dependent: :destroy
  has_one :dispute, dependent: :destroy

  # Instance Methods

  def pix_key_type
    Utils.detect_pix_key_type(pix_key)
  end

  def masked_pix_key
    Utils.mask_sensitive_data(pix_key, :pix_key)
  end

  def infraction_type_description
    I18n.t("infraction_notifications.dropdown_options.infraction_types.#{infraction_type}", default: infraction_type.humanize)
  end

  def created_by_description
    I18n.t("infraction_notifications.dropdown_options.sources.#{created_by}", default: created_by.humanize)
  end

  def created_by_customer_service?
    created_by == InfractionSources::CUSTOMER_SERVICE
  end

  def created_by_customer_experience?
    created_by == InfractionSources::CUSTOMER_EXPERIENCE
  end

  def created_by_dict_automatic?
    created_by == InfractionSources::DICT_AUTOMATIC
  end

  def can_be_cancelled?
    [ InfractionStatus::SUBMITTED, InfractionStatus::PROCESSING ].include?(status)
  end

  # Soft delete implementation - changes status to CANCELLED instead of deleting record
  def soft_delete!(reason: nil, cancelled_by: nil)
    return false unless can_be_cancelled?

    update!(
      status: InfractionStatus::CANCELLED,
      cancelled_at: Time.current,
      cancellation_reason: reason,
      last_status_change_at: Time.current
    )

    # Log the cancellation
    InfractionLog.create!(
      infraction_notification: self,
      level: "info",
      message: "Notification cancelled by #{cancelled_by || 'system'}",
      metadata: {
        action: "soft_delete",
        cancelled_by: cancelled_by,
        reason: reason,
        cancelled_at: Time.current,
      }
    )

    true
  end

  def can_be_analyzed?
    [ InfractionStatus::PROCESSING, InfractionStatus::ANALYZING ].include?(status)
  end

  def pending?
    [ InfractionStatus::SUBMITTED, InfractionStatus::PROCESSING, InfractionStatus::ANALYZING ].include?(status)
  end

  def completed?
    [ InfractionStatus::COMPLETED, InfractionStatus::CANCELLED ].include?(status)
  end

  def days_since_submission
    return 0 unless submitted_at
    ((Time.current - submitted_at) / 1.day).ceil
  end

  # Fraud team dashboard helper methods
  def hours_until_deadline
    hours_since_creation = ((Time.current - created_at) / 1.hour).ceil
    168 - hours_since_creation # 168-hour (7-day) BACEN deadline
  end

  def deadline_urgency_class
    hours_left = hours_until_deadline
    return "deadline-critical" if hours_left <= 24  # Last day
    return "deadline-urgent" if hours_left <= 48    # Last 2 days
    return "deadline-warning" if hours_left <= 72   # Last 3 days
    "deadline-normal"
  end

  def priority_level
    return "high" if high_priority?
    return "medium" if medium_priority?
    "standard"
  end

  def high_priority?
    # Account takeover, SIM swap, high value transactions
    [ "ACCOUNT_TAKEOVER", "SIM_SWAP" ].include?(infraction_type) ||
    (evidence_data.is_a?(Hash) && evidence_data["amount"].to_f > 10000) ||
    (evidence_data.is_a?(Hash) && evidence_data["repeat_violation"] == "true")
  end

  def medium_priority?
    # Phishing, social engineering, suspicious patterns
    [ "PHISHING", "SOCIAL_ENGINEERING", "SUSPICIOUS_TRANSACTION" ].include?(infraction_type) ||
    days_since_submission > 1
  end

  def risk_level
    return "high" if high_priority?
    return "medium" if medium_priority?
    "low"
  end

  def status_description
    Jdpi::StatusCodes::InfractionStatus::DESCRIPTIONS[status] || status.humanize
  end

  def overdue_for_analysis?
    days_since_submission > Duration::MAX_ANALYSIS_DAYS && pending?
  end

  # Dispute-related methods
  def can_be_disputed?
    dispute.nil?
  end

  def has_dispute?
    dispute.present?
  end

  def dispute_deadline
    return nil unless response_due_at
    response_due_at
  end

  def days_until_response_deadline
    return 0 unless response_due_at
    return 0 if response_due_at < Time.current
    ((response_due_at - Time.current) / 1.day).ceil
  end

  def overdue_for_response?
    response_due_at.present? && response_due_at < Time.current
  end

  def update_status!(new_status, notes: nil)
    unless Utils.valid_status_transition?(status, new_status)
      raise ArgumentError, "Invalid status transition from #{status} to #{new_status}"
    end

    update!(
      status: new_status,
      last_status_change_at: Time.current,
      analysis_notes: notes || analysis_notes
    )
  end

  # Update notification with external system response data
  # This is kept generic - JDPI-specific logic should be in service layer
  def update_from_external_response!(response_data)
    attributes_to_update = {}

    # Map external response to domain attributes
    if response_data["notificationId"].present?
      attributes_to_update[:jdpi_notification_id] = response_data["notificationId"]
    end

    if response_data["status"].present?
      attributes_to_update[:status] = response_data["status"]
      attributes_to_update[:last_status_change_at] = Time.current
    end

    if response_data["analysisResult"].present?
      attributes_to_update[:analysis_result] = response_data["analysisResult"]
    end

    if response_data["analysisNotes"].present?
      attributes_to_update[:analysis_notes] = response_data["analysisNotes"]
    end

    if response_data["processedAt"].present?
      attributes_to_update[:processed_at] = Time.parse(response_data["processedAt"])
    end

    update!(attributes_to_update) if attributes_to_update.any?
  end

  # Class Methods

  def self.create_from_service!(pix_key:, infraction_type:, description:, evidence_data: nil, idempotency_key: nil)
    create!(
      pix_key: pix_key,
      infraction_type: infraction_type.to_s.upcase,
      description: description,
      evidence_data: evidence_data,
      status: InfractionStatus::SUBMITTED,
      submitted_at: Time.current,
      idempotency_key: idempotency_key || SecureRandom.uuid
    )
  end

  def self.find_by_external_id(external_notification_id)
    find_by(jdpi_notification_id: external_notification_id)
  end

  def self.statistics
    {
      total: count,
      by_status: group(:status).count,
      by_type: group(:infraction_type).count,
      pending: pending.count,
      completed: completed.count,
      overdue: where("submitted_at < ? AND status IN (?)",
                    Duration::MAX_ANALYSIS_DAYS.days.ago,
                    [ InfractionStatus::SUBMITTED, InfractionStatus::PROCESSING, InfractionStatus::ANALYZING ]).count,
    }
  end

  private

  def normalize_data
    self.pix_key = pix_key&.strip
    self.infraction_type = infraction_type&.strip&.upcase
    self.description = description&.strip
  end

  def set_default_values
    self.status ||= InfractionStatus::SUBMITTED
    self.submitted_at ||= Time.current
    self.idempotency_key ||= Jdpi::IdempotencyService.generate_key
    self.response_due_at ||= 7.days.from_now
    self.days_remaining_to_respond ||= 7
  end

  def update_days_remaining
    if response_due_at.present?
      self.days_remaining_to_respond = days_until_response_deadline
    end
  end

  def validate_pix_key_format
    return if pix_key.blank?

    unless Utils.valid_pix_key?(pix_key)
      errors.add(:pix_key, "has invalid format for any supported PIX key type")
    end
  end

  def validate_status_transitions
    return unless status_changed? && persisted?

    old_status = status_was
    new_status = status

    unless Utils.valid_status_transition?(old_status, new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  def validate_evidence_data_structure
    return if evidence_data.blank?

    unless evidence_data.is_a?(Hash)
      errors.add(:evidence_data, "must be a valid JSON object")
      return
    end

    # Validate evidence data size
    if evidence_data.to_json.bytesize > 64.kilobytes
      errors.add(:evidence_data, "cannot exceed 64KB in size")
    end
  end

  def log_status_change
    Rails.logger.info "[InfractionNotification] Status changed for #{id}: #{status_was} → #{status}"

    # Optional: Create audit log record
    InfractionLog.create!(
      infraction_notification: self,
      level: "info",
      message: "Status changed from #{status_was} to #{status}",
      metadata: {
        action: "status_change",
        old_value: status_was,
        new_value: status,
        changed_at: Time.current,
      }
    )
  end
end

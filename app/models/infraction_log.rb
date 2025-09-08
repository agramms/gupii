# frozen_string_literal: true

# Log model for tracking infraction notification events
# Maintains audit trail of all infraction notification operations
# Domain model - JDPI-specific logic is handled in service layer
class InfractionLog < ApplicationRecord
  # Associations
  belongs_to :infraction_notification

  # Validations
  validates :level, presence: true, inclusion: { in: %w[debug info warn error] }
  validates :message, presence: true
  validates :occurred_at, presence: true

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_level, ->(level) { where(level: level) }
  scope :errors, -> { where(level: "error") }
  scope :warnings, -> { where(level: "warn") }
  scope :info, -> { where(level: "info") }
  scope :debug, -> { where(level: "debug") }

  # Callbacks
  before_validation :set_defaults, on: :create

  class << self
    # Create log entry with current timestamp
    def log!(notification, level, message, metadata = {})
      create!(
        infraction_notification: notification,
        level: level,
        message: message,
        metadata: metadata,
        occurred_at: Time.current
      )
    end
  end

  # metadata column is already JSON type in database - no serialization needed

  private

  def set_defaults
    self.occurred_at ||= Time.current
    self.metadata ||= {}
  end
end
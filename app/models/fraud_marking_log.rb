# Fraud Marking Log Model
# Maintains comprehensive audit trail for all fraud marking activities
# Tracks user actions, system changes, and JDPI API interactions for compliance
class FraudMarkingLog < ApplicationRecord
  # Log levels
  LOG_LEVELS = %w[debug info warn error fatal].freeze
  
  # Common actions for fraud marking lifecycle
  ACTIONS = %w[
    created
    approved
    rejected
    submitted_to_jdpi
    cancelled
    status_changed
    evidence_added
    evidence_removed
    notes_updated
    jdpi_response_received
    error_occurred
    system_update
  ].freeze
  
  # Validations
  validates :fraud_marking, presence: true
  validates :level, presence: true, inclusion: { in: LOG_LEVELS }
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :message, presence: true, length: { maximum: 2000 }
  validates :user, length: { maximum: 255 }
  validates :ip_address, length: { maximum: 45 }
  validates :user_agent, length: { maximum: 500 }
  
  validate :validate_metadata_structure
  
  # Associations
  belongs_to :fraud_marking
  
  # Scopes
  scope :by_level, ->(level) { where(level: level) if level.present? }
  scope :by_action, ->(action) { where(action: action) if action.present? }
  scope :by_user, ->(user) { where(user: user) if user.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :errors, -> { where(level: 'error') }
  scope :user_actions, -> { where.not(user: [nil, 'system']) }
  scope :system_actions, -> { where(user: ['system', nil]) }
  scope :created_after, ->(date) { where('created_at >= ?', date) if date.present? }
  scope :created_before, ->(date) { where('created_at <= ?', date) if date.present? }
  
  # Callbacks
  before_validation :normalize_data
  
  # Instance Methods
  
  def level_badge_class
    case level
    when 'debug' then 'badge-secondary'
    when 'info' then 'badge-primary'
    when 'warn' then 'badge-warning'
    when 'error' then 'badge-danger'
    when 'fatal' then 'badge-dark'
    else 'badge-light'
    end
  end
  
  def action_description
    I18n.t("fraud_marking_logs.actions.#{action}", default: action.humanize)
  end
  
  def user_display
    user.presence || 'System'
  end
  
  def formatted_created_at
    created_at.strftime('%d/%m/%Y %H:%M:%S')
  end
  
  def has_metadata?
    metadata.present? && metadata.any?
  end
  
  def formatted_metadata
    return {} unless has_metadata?
    
    metadata.each_with_object({}) do |(key, value), result|
      formatted_key = key.humanize
      formatted_value = format_metadata_value(value)
      result[formatted_key] = formatted_value
    end
  end
  
  # Class Methods
  
  def self.create_for_action!(fraud_marking:, action:, user: nil, message: nil, **additional_data)
    create!(
      fraud_marking: fraud_marking,
      level: 'info',
      action: action.to_s,
      user: user,
      message: message || "#{action.humanize} executed",
      metadata: additional_data.presence || {},
      ip_address: additional_data[:ip_address],
      user_agent: additional_data[:user_agent]
    )
  end
  
  def self.create_error!(fraud_marking:, message:, exception: nil, user: nil, **additional_data)
    metadata = additional_data
    
    if exception
      metadata.merge!(
        exception_class: exception.class.name,
        exception_message: exception.message,
        backtrace: exception.backtrace&.first(5)
      )
    end
    
    create!(
      fraud_marking: fraud_marking,
      level: 'error',
      action: 'error_occurred',
      user: user,
      message: message,
      metadata: metadata
    )
  end
  
  def self.create_jdpi_interaction!(fraud_marking:, action:, request_data: nil, response_data: nil, user: nil)
    create!(
      fraud_marking: fraud_marking,
      level: 'info',
      action: action.to_s,
      user: user || 'system',
      message: "JDPI #{action.humanize} interaction",
      request_details: request_data&.to_json,
      response_details: response_data&.to_json,
      metadata: {
        jdpi_interaction: true,
        interaction_type: action,
        timestamp: Time.current
      }
    )
  end
  
  def self.audit_trail_for(fraud_marking, limit: 50)
    where(fraud_marking: fraud_marking)
      .order(created_at: :desc)
      .limit(limit)
      .includes(:fraud_marking)
  end
  
  def self.statistics_for_period(start_date, end_date = Time.current)
    logs_in_period = where(created_at: start_date..end_date)
    
    {
      total_logs: logs_in_period.count,
      by_level: logs_in_period.group(:level).count,
      by_action: logs_in_period.group(:action).count,
      errors: logs_in_period.where(level: 'error').count,
      user_actions: logs_in_period.where.not(user: [nil, 'system']).count,
      system_actions: logs_in_period.where(user: ['system', nil]).count
    }
  end
  
  def self.recent_activity(limit: 20)
    includes(:fraud_marking)
      .order(created_at: :desc)
      .limit(limit)
  end
  
  private
  
  def normalize_data
    self.level = level&.downcase&.strip
    self.action = action&.downcase&.strip
    self.user = user&.strip
    self.message = message&.strip
  end
  
  def validate_metadata_structure
    return if metadata.blank?
    
    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a valid JSON object")
      return
    end
    
    # Validate metadata size (prevent abuse)
    if metadata.to_json.bytesize > 32.kilobytes
      errors.add(:metadata, "cannot exceed 32KB in size")
    end
    
    # Validate sensitive data is not logged
    sensitive_keys = %w[password token secret key authorization]
    metadata.keys.each do |key|
      if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
        errors.add(:metadata, "cannot contain sensitive information in key: #{key}")
      end
    end
  end
  
  def format_metadata_value(value)
    case value
    when Hash
      value.map { |k, v| "#{k}: #{v}" }.join(', ')
    when Array
      value.join(', ')
    when Time, DateTime
      value.strftime('%d/%m/%Y %H:%M:%S')
    when TrueClass, FalseClass
      value ? 'Sim' : 'Não'
    else
      value.to_s
    end
  end
end
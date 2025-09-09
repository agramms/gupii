class PaymentServiceProvider < ApplicationRecord
  include ShortId
  
  # Validations for core PSP fields
  validates :ispb, presence: true, uniqueness: true, 
            format: { with: /\A\d{8}\z/, message: "must be 8 digits" }
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :short_name, length: { maximum: 50 }, allow_blank: true
  validates :document_number, presence: true
  validates :document_type, inclusion: { in: %w[CNPJ CPF] }
  
  # Status validations
  validates :status, inclusion: { 
    in: %w[active inactive suspended terminated], 
    message: "must be active, inactive, suspended, or terminated" 
  }
  validates :psp_type, presence: true
  validates :regulatory_status, inclusion: { 
    in: %w[authorized provisional suspended revoked], 
    message: "must be authorized, provisional, suspended, or revoked" 
  }
  
  # Contact information validations
  validates :state, length: { is: 2 }, allow_blank: true, 
            format: { with: /\A[A-Z]{2}\z/, message: "must be 2 uppercase letters" }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  
  # Numerical validations
  validates :total_transactions, numericality: { greater_than_or_equal_to: 0 }
  validates :total_volume, numericality: { greater_than_or_equal_to: 0 }
  validates :sync_attempts, numericality: { greater_than_or_equal_to: 0 }
  validates :availability_percentage, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 100 
  }, allow_blank: true
  
  # JSON field validations
  validates :services_offered, presence: true
  validates :last_sync_errors, presence: true
  validates :jdpi_metadata, presence: true
  validates :validation_errors, presence: true
  
  # Scopes for common queries
  scope :active, -> { where(status: 'active') }
  scope :pix_enabled, -> { where(pix_enabled: true) }
  scope :authorized, -> { where(regulatory_status: 'authorized') }
  scope :needs_sync, -> { where('last_sync_at IS NULL OR last_sync_at < ?', 1.hour.ago) }
  scope :sync_failed, -> { where('sync_attempts > 0 AND last_successful_sync_at IS NULL OR last_successful_sync_at < last_sync_at') }
  scope :recently_updated, -> { where('updated_at > ?', 24.hours.ago) }
  scope :by_state, ->(state) { where(state: state.upcase) if state.present? }
  scope :search_by_name, ->(term) { where('name ILIKE ? OR short_name ILIKE ?', "%#{term}%", "%#{term}%") if term.present? }
  
  # Callbacks
  before_validation :normalize_fields
  before_save :validate_document_number
  after_update :log_status_changes
  
  # Class methods for statistics and reporting
  def self.total_active
    active.count
  end
  
  def self.pix_adoption_rate
    return 0 if count.zero?
    (pix_enabled.count.to_f / count * 100).round(2)
  end
  
  def self.sync_health_summary
    {
      total: count,
      needs_sync: needs_sync.count,
      sync_failed: sync_failed.count,
      last_successful_sync: maximum(:last_successful_sync_at)
    }
  end
  
  def self.top_by_volume(limit = 10)
    where.not(total_volume: 0)
         .order(total_volume: :desc)
         .limit(limit)
  end
  
  # Instance methods
  def pix_services
    services_offered.select { |service| service.to_s.downcase.include?('pix') }
  end
  
  def sync_status
    return 'never_synced' if last_sync_at.nil?
    return 'sync_failed' if sync_attempts > 0 && (last_successful_sync_at.nil? || last_successful_sync_at < last_sync_at)
    return 'needs_sync' if last_sync_at < 1.hour.ago
    'up_to_date'
  end
  
  def sync_health_score
    return 0 if last_sync_at.nil?
    return 25 if sync_status == 'sync_failed'
    return 50 if sync_status == 'needs_sync'
    
    # Calculate based on availability and error rate
    base_score = 75
    base_score += 25 if availability_percentage && availability_percentage > 99.5
    base_score -= (error_count_24h * 2) if error_count_24h > 0
    [base_score, 100].min
  end
  
  def operational_status
    return 'inactive' unless status == 'active'
    return 'unauthorized' unless regulatory_status == 'authorized'
    return 'pix_disabled' unless pix_enabled?
    return 'degraded' if sync_health_score < 50
    'operational'
  end
  
  def display_name
    short_name.present? ? short_name : name
  end
  
  def formatted_document
    case document_type
    when 'CNPJ'
      document_number.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\1.\2.\3/\4-\5')
    when 'CPF'
      document_number.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4')
    else
      document_number
    end
  end
  
  def sync_status_badge_class
    case sync_status
    when 'up_to_date'
      'bg-green-100 text-green-800'
    when 'needs_sync'
      'bg-yellow-100 text-yellow-800'
    when 'sync_failed'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  
  def last_activity
    [last_transaction_at, last_sync_at, updated_at].compact.max
  end
  
  private
  
  def normalize_fields
    self.ispb = ispb&.strip
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.document_number = document_number&.gsub(/\D/, '') # Remove non-digits
    self.state = state&.upcase
    self.contact_email = contact_email&.strip&.downcase
  end
  
  def validate_document_number
    case document_type
    when 'CNPJ'
      errors.add(:document_number, 'must be 14 digits for CNPJ') unless document_number&.length == 14
    when 'CPF'
      errors.add(:document_number, 'must be 11 digits for CPF') unless document_number&.length == 11
    end
  end
  
  def log_status_changes
    if saved_change_to_status?
      Rails.logger.info "[PSP #{display_id}] Status changed from #{status_was} to #{status}"
    end
    
    if saved_change_to_regulatory_status?
      Rails.logger.info "[PSP #{display_id}] Regulatory status changed from #{regulatory_status_was} to #{regulatory_status}"
    end
  end
end
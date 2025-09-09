class CreatePaymentServiceProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_service_providers, id: false do |t|
      # Primary key using UUID
      t.uuid :id, primary_key: true, default: -> { "gen_random_uuid()" }
      
      # Core PSP identification (JDPI fields)
      t.string :ispb, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :short_name, limit: 50
      t.string :document_number, null: false
      t.string :document_type, null: false, default: 'CNPJ'
      
      # PSP Status and Classification
      t.string :status, null: false, default: 'active'
      t.string :psp_type, null: false
      t.json :services_offered, default: []
      t.boolean :pix_enabled, default: true
      
      # Compliance and Authorization
      t.string :bacen_authorization_number
      t.date :authorization_date
      t.date :authorization_expiry
      t.string :regulatory_status, default: 'authorized'
      
      # Contact and Location Information
      t.string :legal_address
      t.string :city
      t.string :state, limit: 2
      t.string :postal_code
      t.string :contact_phone
      t.string :contact_email
      t.string :website
      
      # Operational Metrics (for monitoring)
      t.integer :total_transactions, default: 0
      t.decimal :total_volume, precision: 15, scale: 2, default: 0.0
      t.datetime :last_transaction_at
      
      # JDPI Sync and Monitoring Fields
      t.datetime :last_sync_at
      t.datetime :last_successful_sync_at
      t.integer :sync_attempts, default: 0
      t.json :last_sync_errors, default: []
      t.string :jdpi_status
      t.json :jdpi_metadata, default: {}
      
      # Data Quality and Validation
      t.boolean :data_validated, default: false
      t.datetime :last_validation_at
      t.json :validation_errors, default: []
      t.string :data_source, default: 'jdpi'
      
      # Performance Monitoring
      t.decimal :avg_response_time_ms, precision: 8, scale: 2
      t.integer :error_count_24h, default: 0
      t.decimal :availability_percentage, precision: 5, scale: 2, default: 100.0
      t.datetime :last_health_check_at
      
      # Audit Fields
      t.string :created_by
      t.string :updated_by
      t.timestamps null: false
      
      # Additional indexes for performance
      t.index :status
      t.index :psp_type
      t.index :last_sync_at
      t.index :pix_enabled
      t.index [:status, :pix_enabled]
      t.index :regulatory_status
      t.index :data_validated
    end
    
    # Add comments for documentation
    execute <<-SQL
      COMMENT ON TABLE payment_service_providers IS 'Payment Service Providers (PSPs) from JDPI API with monitoring capabilities';
      COMMENT ON COLUMN payment_service_providers.ispb IS 'Identifier of the Payment System Participant (ISPB) - unique identifier in the Brazilian Payment System';
      COMMENT ON COLUMN payment_service_providers.services_offered IS 'JSON array of PIX services offered by the PSP';
      COMMENT ON COLUMN payment_service_providers.jdpi_metadata IS 'Additional metadata from JDPI API responses';
      COMMENT ON COLUMN payment_service_providers.last_sync_errors IS 'JSON array of recent synchronization errors for monitoring';
    SQL
  end
end
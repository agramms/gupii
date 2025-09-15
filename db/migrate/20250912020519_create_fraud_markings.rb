class CreateFraudMarkings < ActiveRecord::Migration[8.0]
  def change
    create_table :fraud_markings, id: :uuid do |t|
      # PIX Key Information
      t.string :pix_key, null: false, limit: 77
      t.string :pix_key_type, null: false, limit: 20
      t.string :masked_pix_key, limit: 77

      # Fraud Type and Classification
      t.string :fraud_type, null: false, limit: 50
      t.string :sub_fraud_type, limit: 50
      t.string :classification, null: false, limit: 30

      # Status Management
      t.string :status, null: false, limit: 20, default: 'PENDING'
      t.timestamp :status_changed_at

      # Description and Evidence
      t.text :description, null: false
      t.text :detailed_description
      t.jsonb :evidence_data
      t.text :supporting_details

      # JDPI Integration Fields
      t.string :jdpi_marking_id, limit: 36
      t.string :idempotency_key, null: false, limit: 36
      t.timestamp :submitted_at
      t.timestamp :processed_at

      # Approval Workflow
      t.string :requested_by, null: false, limit: 255
      t.string :approved_by, limit: 255
      t.timestamp :approved_at
      t.string :rejection_reason, limit: 500

      # Cancellation Information
      t.string :cancelled_by, limit: 255
      t.timestamp :cancelled_at
      t.text :cancellation_reason

      # Risk Assessment
      t.string :risk_level, limit: 20
      t.integer :risk_score
      t.decimal :transaction_amount, precision: 15, scale: 2
      t.string :transaction_currency, limit: 3, default: 'BRL'

      # Compliance and Audit
      t.string :created_by_source, null: false, limit: 50
      t.string :institution_code, limit: 8
      t.boolean :requires_supervisor_approval, default: true
      t.boolean :sensitive_case, default: false

      # Deadline Management
      t.timestamp :response_due_at
      t.integer :days_remaining_to_respond

      # Additional Metadata
      t.jsonb :metadata
      t.text :internal_notes
      t.string :reference_case_id, limit: 36

      t.timestamps

      # Indexes
      t.index :pix_key, name: 'index_fraud_markings_on_pix_key'
      t.index :status, name: 'index_fraud_markings_on_status'
      t.index :fraud_type, name: 'index_fraud_markings_on_fraud_type'
      t.index :jdpi_marking_id, unique: true, name: 'index_fraud_markings_on_jdpi_marking_id'
      t.index :idempotency_key, unique: true, name: 'index_fraud_markings_on_idempotency_key'
      t.index :requested_by, name: 'index_fraud_markings_on_requested_by'
      t.index :created_at, name: 'index_fraud_markings_on_created_at'
      t.index :submitted_at, name: 'index_fraud_markings_on_submitted_at'
      t.index [ :status, :created_at ], name: 'index_fraud_markings_on_status_and_created_at'
      t.index [ :pix_key, :fraud_type ], name: 'index_fraud_markings_on_pix_key_and_fraud_type'
    end
  end
end

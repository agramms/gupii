# frozen_string_literal: true

class CreateInfractionNotifications < ActiveRecord::Migration[8.0]
  def change
    # Infraction Notifications table
    create_table :infraction_notifications, id: :uuid do |t|
      # JDPI identifiers
      t.string :jdpi_notification_id, null: true, index: { unique: true }
      t.string :idempotency_key, null: false, index: { unique: true }
      
      # PIX key information
      t.string :pix_key, null: false, index: true, limit: 77
      
      # Infraction details
      t.string :infraction_type, null: false, index: true
      t.text :description, null: false, limit: 500
      t.json :evidence_data
      
      # Status tracking
      t.string :status, null: false, default: "SUBMITTED", index: true
      t.timestamp :submitted_at
      t.timestamp :last_status_change_at
      t.timestamp :processed_at
      t.timestamp :cancelled_at
      
      # Analysis information
      t.string :analysis_result
      t.text :analysis_notes, limit: 1000
      
      # Cancellation information
      t.text :cancellation_reason
      
      # Standard timestamps
      t.timestamps
      
      # Indexes for efficient querying
      t.index [:status, :created_at]
      t.index [:infraction_type, :created_at]
      t.index [:pix_key, :status]
      t.index [:submitted_at]
      t.index [:last_status_change_at]
    end

    # Infraction Logs table for audit trail
    create_table :infraction_logs, id: :uuid do |t|
      t.references :infraction_notification, 
                   type: :uuid, 
                   null: false, 
                   foreign_key: { on_delete: :cascade },
                   index: { name: 'idx_infraction_logs_on_notification' }
      
      # Log details
      t.string :level, null: false, default: "info"
      t.text :message, null: false
      t.json :metadata, default: {}
      t.timestamp :occurred_at, null: false
      
      # Indexes for log querying
      t.index [:level, :occurred_at]
      t.index [:occurred_at]
    end

    # Add comments for documentation
    add_column_comment :infraction_notifications, :jdpi_notification_id, 
                      "JDPI notification identifier returned by API"
    add_column_comment :infraction_notifications, :idempotency_key, 
                      "36-character UUID for request deduplication"
    add_column_comment :infraction_notifications, :pix_key, 
                      "PIX key value (CPF/CNPJ/Email/Phone/UUID)"
    add_column_comment :infraction_notifications, :infraction_type, 
                      "Type of infraction (FRAUD, AML_VIOLATION, etc.)"
    add_column_comment :infraction_notifications, :evidence_data, 
                      "JSON evidence supporting the infraction claim"
    add_column_comment :infraction_notifications, :status,
                      "Current status in lifecycle"
    
    add_column_comment :infraction_logs, :level, 
                      "Log level: debug, info, warn, error"
    add_column_comment :infraction_logs, :metadata, 
                      "Additional contextual information for the log entry"
  end
end
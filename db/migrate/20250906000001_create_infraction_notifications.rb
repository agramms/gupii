# frozen_string_literal: true

class CreateInfractionNotifications < ActiveRecord::Migration[8.0]
  def change
    # Infraction Notifications table
    create_table :infraction_notifications, id: :uuid, comment: "PIX key infraction notifications tracking" do |t|
      # JDPI identifiers
      t.string :jdpi_notification_id, null: true, index: { unique: true }, comment: "JDPI notification identifier returned by API"
      t.string :idempotency_key, null: false, index: { unique: true }, comment: "36-character UUID for request deduplication"
      
      # PIX key information
      t.string :pix_key, null: false, index: true, limit: 77, comment: "PIX key value (CPF/CNPJ/Email/Phone/UUID)"
      
      # Infraction details
      t.string :infraction_type, null: false, index: true, comment: "Type of infraction (FRAUD, AML_VIOLATION, etc.)"
      t.text :description, null: false, limit: 500, comment: "Description of the infraction"
      t.json :evidence_data, comment: "JSON evidence supporting the infraction claim"
      
      # Status tracking
      t.string :status, null: false, default: "SUBMITTED", index: true, comment: "Current status in lifecycle"
      t.timestamp :submitted_at, comment: "When notification was submitted to JDPI"
      t.timestamp :last_status_change_at, comment: "Last time status was updated"
      t.timestamp :processed_at, comment: "When JDPI finished processing"
      t.timestamp :cancelled_at, comment: "When notification was cancelled"
      
      # Analysis information
      t.string :analysis_result, comment: "Result of JDPI analysis (CONFIRMED, REJECTED, etc.)"
      t.text :analysis_notes, limit: 1000, comment: "Notes from analysis process"
      
      # Cancellation information
      t.text :cancellation_reason, comment: "Reason for cancellation"
      
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
    create_table :infraction_logs, id: :uuid, comment: "Audit trail for infraction notification changes" do |t|
      t.references :infraction_notification, 
                   type: :uuid, 
                   null: false, 
                   foreign_key: { on_delete: :cascade },
                   index: { name: 'idx_infraction_logs_on_notification' }
      
      # Log details
      t.string :level, null: false, default: "info", comment: "Log level: debug, info, warn, error"
      t.text :message, null: false, comment: "Log message describing the action"
      t.json :metadata, default: {}, comment: "Additional contextual information for the log entry"
      t.timestamp :occurred_at, null: false, comment: "When the logged action occurred"
      
      # Indexes for log querying
      t.index [:level, :occurred_at]
      t.index [:occurred_at]
    end
  end
end
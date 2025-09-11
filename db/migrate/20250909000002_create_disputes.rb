class CreateDisputes < ActiveRecord::Migration[8.0]
  def change
    create_table :disputes, id: :uuid do |t|
      # Association with infraction notification (one-to-one relationship)
      t.references :infraction_notification, null: false, foreign_key: true, type: :uuid
      
      # Dispute core fields
      t.integer :dispute_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :justification, null: false
      t.text :evidence_notes
      t.jsonb :additional_data, default: {}
      
      # Internal workflow tracking
      t.string :created_by, null: false
      t.string :assigned_to
      t.string :reviewed_by
      
      # Timeline tracking
      t.timestamp :submitted_at
      t.timestamp :reviewed_at
      t.timestamp :resolved_at
      t.timestamp :customer_response_due_at, null: false
      
      # Resolution
      t.text :resolution_notes
      t.text :next_actions
      t.string :final_decision # approved, rejected, escalated
      
      # Audit fields
      t.timestamps
      t.timestamp :deleted_at
      t.string :deleted_by
      t.text :deletion_reason
      
      # Indexes for performance
      t.index :infraction_notification_id, unique: true, name: 'index_disputes_on_infraction_notification'
      t.index :status
      t.index :dispute_type
      t.index :customer_response_due_at
      t.index [:status, :customer_response_due_at], name: 'index_disputes_on_status_and_due_date'
      t.index :created_at
      t.index :deleted_at
    end
    
    # Add dispute status to infraction notifications
    add_column :infraction_notifications, :dispute_status, :integer, default: 0
    add_index :infraction_notifications, :dispute_status
    
    # Add dispute timeline fields to infraction notifications
    add_column :infraction_notifications, :response_due_at, :timestamp
    add_column :infraction_notifications, :days_remaining_to_respond, :integer
    
    # Create index for timeline queries
    add_index :infraction_notifications, :response_due_at
    add_index :infraction_notifications, [:status, :response_due_at], name: 'index_infractions_on_status_and_due_date'
  end
end
class CreateFraudMarkingLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :fraud_marking_logs, id: :uuid do |t|
      # Association
      t.references :fraud_marking, null: false, foreign_key: true, type: :uuid
      
      # Log Information
      t.string :level, null: false, limit: 10
      t.string :action, null: false, limit: 50
      t.string :user, limit: 255
      t.text :message, null: false
      
      # Metadata and Context
      t.jsonb :metadata
      t.text :request_details
      t.text :response_details
      t.string :ip_address, limit: 45
      t.string :user_agent, limit: 500
      
      t.timestamps
      
      # Indexes
      t.index :fraud_marking_id, name: 'idx_fraud_marking_logs_on_fraud_marking_id'
      t.index :level, name: 'idx_fraud_marking_logs_on_level'
      t.index :action, name: 'idx_fraud_marking_logs_on_action'
      t.index :created_at, name: 'idx_fraud_marking_logs_on_created_at'
      t.index [:fraud_marking_id, :created_at], name: 'idx_fraud_marking_logs_on_marking_and_created_at'
    end
  end
end

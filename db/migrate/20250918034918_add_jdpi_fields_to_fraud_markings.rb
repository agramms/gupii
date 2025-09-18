class AddJdpiFieldsToFraudMarkings < ActiveRecord::Migration[8.0]
  def change
    add_column :fraud_markings, :jdpi_response_data, :jsonb
    add_column :fraud_markings, :submission_errors, :jsonb
    add_column :fraud_markings, :evidence_description, :text
    add_column :fraud_markings, :reported_by, :string
  end
end

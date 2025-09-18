class ChangeRiskScoreToDecimalInFraudMarkings < ActiveRecord::Migration[8.0]
  def change
    change_column :fraud_markings, :risk_score, :decimal, precision: 5, scale: 3
  end
end

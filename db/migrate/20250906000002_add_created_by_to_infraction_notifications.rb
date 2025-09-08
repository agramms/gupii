# frozen_string_literal: true

class AddCreatedByToInfractionNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :infraction_notifications, :created_by, :string, null: false, default: 'DICT_AUTOMATIC', comment: "Source that created the infraction (CUSTOMER_SERVICE, CUSTOMER_EXPERIENCE, DICT_AUTOMATIC)"
    add_index :infraction_notifications, :created_by
  end
end
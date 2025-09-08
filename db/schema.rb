# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_06_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "infraction_logs", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Audit trail for infraction notification changes", force: :cascade do |t|
    t.uuid "infraction_notification_id", null: false
    t.string "level", default: "info", null: false, comment: "Log level: debug, info, warn, error"
    t.text "message", null: false, comment: "Log message describing the action"
    t.json "metadata", default: {}, comment: "Additional contextual information for the log entry"
    t.datetime "occurred_at", precision: nil, null: false, comment: "When the logged action occurred"
    t.index ["infraction_notification_id"], name: "idx_infraction_logs_on_notification"
    t.index ["level", "occurred_at"], name: "index_infraction_logs_on_level_and_occurred_at"
    t.index ["occurred_at"], name: "index_infraction_logs_on_occurred_at"
  end

  create_table "infraction_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "PIX key infraction notifications tracking", force: :cascade do |t|
    t.string "jdpi_notification_id", comment: "JDPI notification identifier returned by API"
    t.string "idempotency_key", null: false, comment: "36-character UUID for request deduplication"
    t.string "pix_key", limit: 77, null: false, comment: "PIX key value (CPF/CNPJ/Email/Phone/UUID)"
    t.string "infraction_type", null: false, comment: "Type of infraction (FRAUD, AML_VIOLATION, etc.)"
    t.text "description", null: false, comment: "Description of the infraction"
    t.json "evidence_data", comment: "JSON evidence supporting the infraction claim"
    t.string "status", default: "SUBMITTED", null: false, comment: "Current status in lifecycle"
    t.datetime "submitted_at", precision: nil, comment: "When notification was submitted to JDPI"
    t.datetime "last_status_change_at", precision: nil, comment: "Last time status was updated"
    t.datetime "processed_at", precision: nil, comment: "When JDPI finished processing"
    t.datetime "cancelled_at", precision: nil, comment: "When notification was cancelled"
    t.string "analysis_result", comment: "Result of JDPI analysis (CONFIRMED, REJECTED, etc.)"
    t.text "analysis_notes", comment: "Notes from analysis process"
    t.text "cancellation_reason", comment: "Reason for cancellation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "created_by", default: "DICT_AUTOMATIC", null: false, comment: "Source that created the infraction (CUSTOMER_SERVICE, CUSTOMER_EXPERIENCE, DICT_AUTOMATIC)"
    t.index ["created_by"], name: "index_infraction_notifications_on_created_by"
    t.index ["idempotency_key"], name: "index_infraction_notifications_on_idempotency_key", unique: true
    t.index ["infraction_type", "created_at"], name: "idx_on_infraction_type_created_at_4339c8d09a"
    t.index ["infraction_type"], name: "index_infraction_notifications_on_infraction_type"
    t.index ["jdpi_notification_id"], name: "index_infraction_notifications_on_jdpi_notification_id", unique: true
    t.index ["last_status_change_at"], name: "index_infraction_notifications_on_last_status_change_at"
    t.index ["pix_key", "status"], name: "index_infraction_notifications_on_pix_key_and_status"
    t.index ["pix_key"], name: "index_infraction_notifications_on_pix_key"
    t.index ["status", "created_at"], name: "index_infraction_notifications_on_status_and_created_at"
    t.index ["status"], name: "index_infraction_notifications_on_status"
    t.index ["submitted_at"], name: "index_infraction_notifications_on_submitted_at"
  end

  add_foreign_key "infraction_logs", "infraction_notifications", on_delete: :cascade
end

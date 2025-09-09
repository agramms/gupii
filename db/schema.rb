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

ActiveRecord::Schema[8.0].define(version: 2025_09_09_000001) do
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

  create_table "payment_service_providers", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Payment Service Providers (PSPs) from JDPI API with monitoring capabilities", force: :cascade do |t|
    t.string "ispb", null: false, comment: "Identifier of the Payment System Participant (ISPB) - unique identifier in the Brazilian Payment System"
    t.string "name", null: false
    t.string "short_name", limit: 50
    t.string "document_number", null: false
    t.string "document_type", default: "CNPJ", null: false
    t.string "status", default: "active", null: false
    t.string "psp_type", null: false
    t.json "services_offered", default: [], comment: "JSON array of PIX services offered by the PSP"
    t.boolean "pix_enabled", default: true
    t.string "bacen_authorization_number"
    t.date "authorization_date"
    t.date "authorization_expiry"
    t.string "regulatory_status", default: "authorized"
    t.string "legal_address"
    t.string "city"
    t.string "state", limit: 2
    t.string "postal_code"
    t.string "contact_phone"
    t.string "contact_email"
    t.string "website"
    t.integer "total_transactions", default: 0
    t.decimal "total_volume", precision: 15, scale: 2, default: "0.0"
    t.datetime "last_transaction_at"
    t.datetime "last_sync_at"
    t.datetime "last_successful_sync_at"
    t.integer "sync_attempts", default: 0
    t.json "last_sync_errors", default: [], comment: "JSON array of recent synchronization errors for monitoring"
    t.string "jdpi_status"
    t.json "jdpi_metadata", default: {}, comment: "Additional metadata from JDPI API responses"
    t.boolean "data_validated", default: false
    t.datetime "last_validation_at"
    t.json "validation_errors", default: []
    t.string "data_source", default: "jdpi"
    t.decimal "avg_response_time_ms", precision: 8, scale: 2
    t.integer "error_count_24h", default: 0
    t.decimal "availability_percentage", precision: 5, scale: 2, default: "100.0"
    t.datetime "last_health_check_at"
    t.string "created_by"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_validated"], name: "index_payment_service_providers_on_data_validated"
    t.index ["ispb"], name: "index_payment_service_providers_on_ispb", unique: true
    t.index ["last_sync_at"], name: "index_payment_service_providers_on_last_sync_at"
    t.index ["pix_enabled"], name: "index_payment_service_providers_on_pix_enabled"
    t.index ["psp_type"], name: "index_payment_service_providers_on_psp_type"
    t.index ["regulatory_status"], name: "index_payment_service_providers_on_regulatory_status"
    t.index ["status", "pix_enabled"], name: "index_payment_service_providers_on_status_and_pix_enabled"
    t.index ["status"], name: "index_payment_service_providers_on_status"
  end

  add_foreign_key "infraction_logs", "infraction_notifications", on_delete: :cascade
end

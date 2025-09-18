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

ActiveRecord::Schema[8.0].define(version: 2025_09_18_041520) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "disputes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "infraction_notification_id", null: false
    t.integer "dispute_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "justification", null: false
    t.text "evidence_notes"
    t.jsonb "additional_data", default: {}
    t.string "created_by", null: false
    t.string "assigned_to"
    t.string "reviewed_by"
    t.datetime "submitted_at", precision: nil
    t.datetime "reviewed_at", precision: nil
    t.datetime "resolved_at", precision: nil
    t.datetime "customer_response_due_at", precision: nil, null: false
    t.text "resolution_notes"
    t.text "next_actions"
    t.string "final_decision"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at", precision: nil
    t.string "deleted_by"
    t.text "deletion_reason"
    t.index ["created_at"], name: "index_disputes_on_created_at"
    t.index ["customer_response_due_at"], name: "index_disputes_on_customer_response_due_at"
    t.index ["deleted_at"], name: "index_disputes_on_deleted_at"
    t.index ["dispute_type"], name: "index_disputes_on_dispute_type"
    t.index ["infraction_notification_id"], name: "index_disputes_on_infraction_notification", unique: true
    t.index ["infraction_notification_id"], name: "index_disputes_on_infraction_notification_id"
    t.index ["status", "customer_response_due_at"], name: "index_disputes_on_status_and_due_date"
    t.index ["status"], name: "index_disputes_on_status"
  end

  create_table "fraud_marking_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "fraud_marking_id", null: false
    t.string "level", limit: 10, null: false
    t.string "action", limit: 50, null: false
    t.string "user", limit: 255
    t.text "message", null: false
    t.jsonb "metadata"
    t.text "request_details"
    t.text "response_details"
    t.string "ip_address", limit: 45
    t.string "user_agent", limit: 500
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "idx_fraud_marking_logs_on_action"
    t.index ["created_at"], name: "idx_fraud_marking_logs_on_created_at"
    t.index ["fraud_marking_id", "created_at"], name: "idx_fraud_marking_logs_on_marking_and_created_at"
    t.index ["fraud_marking_id"], name: "idx_fraud_marking_logs_on_fraud_marking_id"
    t.index ["fraud_marking_id"], name: "index_fraud_marking_logs_on_fraud_marking_id"
    t.index ["level"], name: "idx_fraud_marking_logs_on_level"
  end

  create_table "fraud_markings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "pix_key", limit: 77, null: false
    t.string "pix_key_type", limit: 20, null: false
    t.string "masked_pix_key", limit: 77
    t.string "fraud_type", limit: 50, null: false
    t.string "sub_fraud_type", limit: 50
    t.string "classification", limit: 30, null: false
    t.string "status", limit: 20, default: "PENDING", null: false
    t.datetime "status_changed_at", precision: nil
    t.text "description", null: false
    t.text "detailed_description"
    t.jsonb "evidence_data"
    t.text "supporting_details"
    t.string "jdpi_marking_id", limit: 36
    t.string "idempotency_key", limit: 36, null: false
    t.datetime "submitted_at", precision: nil
    t.datetime "processed_at", precision: nil
    t.string "requested_by", limit: 255, null: false
    t.string "approved_by", limit: 255
    t.datetime "approved_at", precision: nil
    t.string "rejection_reason", limit: 500
    t.string "cancelled_by", limit: 255
    t.datetime "cancelled_at", precision: nil
    t.text "cancellation_reason"
    t.string "risk_level", limit: 20
    t.decimal "risk_score", precision: 5, scale: 3
    t.decimal "transaction_amount", precision: 15, scale: 2
    t.string "transaction_currency", limit: 3, default: "BRL"
    t.string "created_by_source", limit: 50, null: false
    t.string "institution_code", limit: 8
    t.boolean "requires_supervisor_approval", default: true
    t.boolean "sensitive_case", default: false
    t.datetime "response_due_at", precision: nil
    t.integer "days_remaining_to_respond"
    t.jsonb "metadata"
    t.text "internal_notes"
    t.string "reference_case_id", limit: 36
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "jdpi_response_data"
    t.jsonb "submission_errors"
    t.text "evidence_description"
    t.string "reported_by"
    t.index ["created_at"], name: "index_fraud_markings_on_created_at"
    t.index ["fraud_type"], name: "index_fraud_markings_on_fraud_type"
    t.index ["idempotency_key"], name: "index_fraud_markings_on_idempotency_key", unique: true
    t.index ["jdpi_marking_id"], name: "index_fraud_markings_on_jdpi_marking_id", unique: true
    t.index ["pix_key", "fraud_type"], name: "index_fraud_markings_on_pix_key_and_fraud_type"
    t.index ["pix_key"], name: "index_fraud_markings_on_pix_key"
    t.index ["requested_by"], name: "index_fraud_markings_on_requested_by"
    t.index ["status", "created_at"], name: "index_fraud_markings_on_status_and_created_at"
    t.index ["status"], name: "index_fraud_markings_on_status"
    t.index ["submitted_at"], name: "index_fraud_markings_on_submitted_at"
  end

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
    t.integer "dispute_status", default: 0
    t.datetime "response_due_at", precision: nil
    t.integer "days_remaining_to_respond"
    t.index ["created_by"], name: "index_infraction_notifications_on_created_by"
    t.index ["dispute_status"], name: "index_infraction_notifications_on_dispute_status"
    t.index ["idempotency_key"], name: "index_infraction_notifications_on_idempotency_key", unique: true
    t.index ["infraction_type", "created_at"], name: "idx_on_infraction_type_created_at_4339c8d09a"
    t.index ["infraction_type"], name: "index_infraction_notifications_on_infraction_type"
    t.index ["jdpi_notification_id"], name: "index_infraction_notifications_on_jdpi_notification_id", unique: true
    t.index ["last_status_change_at"], name: "index_infraction_notifications_on_last_status_change_at"
    t.index ["pix_key", "status"], name: "index_infraction_notifications_on_pix_key_and_status"
    t.index ["pix_key"], name: "index_infraction_notifications_on_pix_key"
    t.index ["response_due_at"], name: "index_infraction_notifications_on_response_due_at"
    t.index ["status", "created_at"], name: "index_infraction_notifications_on_status_and_created_at"
    t.index ["status", "response_due_at"], name: "index_infractions_on_status_and_due_date"
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

  add_foreign_key "disputes", "infraction_notifications"
  add_foreign_key "fraud_marking_logs", "fraud_markings"
  add_foreign_key "infraction_logs", "infraction_notifications", on_delete: :cascade
end

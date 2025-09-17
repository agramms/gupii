# frozen_string_literal: true

# Fraud Marking Export Service
# Handles data export for fraud markings in CSV and Excel formats
# Includes compliance and audit trail information
class FraudMarkingExportService
  include ActiveModel::Model

  attr_reader :fraud_markings, :options

  def initialize(fraud_markings, options = {})
    @fraud_markings = fraud_markings
    @options = {
      include_logs: true,
      include_evidence_summary: true,
      mask_sensitive_data: true,
      format_dates: true,
    }.merge(options)
  end

  # Generate CSV export
  def to_csv
    require "csv"

    CSV.generate(headers: true) do |csv|
      # Add header row
      csv << csv_headers

      # Add data rows
      @fraud_markings.includes(:fraud_marking_logs, evidence_files_attachments: :blob).find_each do |marking|
        csv << format_row_for_csv(marking)
      end
    end
  end

  # Generate Excel export (requires additional gem in production)
  def to_xlsx
    # This would require the 'axlsx' or 'xlsx_writer' gem
    # For now, return CSV format as fallback
    to_csv
  end

  # Generate detailed report with compliance information
  def to_compliance_report
    {
      export_metadata: export_metadata,
      summary: generate_summary,
      markings: @fraud_markings.map { |marking| format_detailed_marking(marking) },
    }.to_json(indent: 2)
  end

  private

  def csv_headers
    headers = [
      "ID",
      "Short ID",
      "PIX Key",
      "PIX Key Type",
      "Fraud Type",
      "Classification",
      "Risk Level",
      "Priority Level",
      "Status",
      "Description",
      "Transaction Amount",
      "Currency",
      "Created By Source",
      "Requested By",
      "Approved By",
      "Approved At",
      "Created At",
      "Response Due At",
      "Days Remaining",
      "JDPI Marking ID",
      "Reference Case ID",
      "Sensitive Case",
      "Requires Approval",
    ]

    if @options[:include_evidence_summary]
      headers += [
        "Evidence Files Count",
        "Evidence Total Size",
        "Evidence File Types",
      ]
    end

    if @options[:include_logs]
      headers += [
        "Last Activity",
        "Last Activity User",
        "Total Log Entries",
      ]
    end

    headers
  end

  def format_row_for_csv(marking)
    row = [
      marking.id,
      marking.short_id,
      @options[:mask_sensitive_data] ? marking.masked_pix_key_display : marking.pix_key,
      marking.pix_key_type,
      marking.fraud_type_description,
      marking.classification_description,
      marking.risk_level_description,
      I18n.t("fraud_markings.priority_levels.#{marking.priority_level}"),
      marking.status_description,
      truncate_text(marking.description, 200),
      marking.transaction_amount&.to_f,
      marking.transaction_currency,
      marking.source_description,
      marking.requested_by,
      marking.approved_by,
      format_datetime(marking.approved_at),
      format_datetime(marking.created_at),
      format_datetime(marking.response_due_at),
      marking.days_until_deadline,
      marking.jdpi_marking_id,
      marking.reference_case_id,
      marking.sensitive_case? ? "Yes" : "No",
      marking.requires_supervisor_approval? ? "Yes" : "No",
    ]

    if @options[:include_evidence_summary]
      evidence_summary = get_evidence_summary(marking)
      row += [
        evidence_summary[:count],
        evidence_summary[:total_size_human],
        evidence_summary[:file_types].join(", "),
      ]
    end

    if @options[:include_logs]
      last_log = marking.fraud_marking_logs.recent.first
      row += [
        last_log ? format_datetime(last_log.created_at) : "",
        last_log&.user_display || "",
        marking.fraud_marking_logs.count,
      ]
    end

    row
  end

  def format_detailed_marking(marking)
    {
      id: marking.id,
      short_id: marking.short_id,
      pix_key_info: {
        pix_key: @options[:mask_sensitive_data] ? marking.masked_pix_key_display : marking.pix_key,
        pix_key_type: marking.pix_key_type,
      },
      fraud_details: {
        fraud_type: marking.fraud_type,
        fraud_type_description: marking.fraud_type_description,
        sub_fraud_type: marking.sub_fraud_type,
        classification: marking.classification,
        classification_description: marking.classification_description,
        risk_level: marking.risk_level,
        priority_level: marking.priority_level,
      },
      status_info: {
        status: marking.status,
        status_description: marking.status_description,
        created_at: format_datetime(marking.created_at),
        status_changed_at: format_datetime(marking.status_changed_at),
        response_due_at: format_datetime(marking.response_due_at),
        days_until_deadline: marking.days_until_deadline,
        overdue: marking.overdue_for_response?,
      },
      approval_info: {
        requested_by: marking.requested_by,
        approved_by: marking.approved_by,
        approved_at: format_datetime(marking.approved_at),
        requires_supervisor_approval: marking.requires_supervisor_approval?,
      },
      descriptions: {
        description: marking.description,
        detailed_description: marking.detailed_description,
        supporting_details: marking.supporting_details,
        internal_notes: @options[:mask_sensitive_data] ? "[MASKED]" : marking.internal_notes,
      },
      financial_info: {
        transaction_amount: marking.transaction_amount&.to_f,
        transaction_currency: marking.transaction_currency,
      },
      case_management: {
        created_by_source: marking.created_by_source,
        reference_case_id: marking.reference_case_id,
        sensitive_case: marking.sensitive_case?,
      },
      jdpi_integration: {
        jdpi_marking_id: marking.jdpi_marking_id,
        submitted_at: format_datetime(marking.submitted_at),
        processed_at: format_datetime(marking.processed_at),
      },
      evidence: @options[:include_evidence_summary] ? get_evidence_summary(marking) : nil,
      activity_logs: @options[:include_logs] ? format_activity_logs(marking) : nil,
    }
  end

  def get_evidence_summary(marking)
    files = marking.evidence_files

    {
      count: files.count,
      total_size: files.sum(&:byte_size),
      total_size_human: ActiveSupport::NumberHelper.number_to_human_size(files.sum(&:byte_size)),
      file_types: files.map(&:content_type).uniq,
      files: files.map do |file|
        {
          filename: file.filename.to_s,
          content_type: file.content_type,
          size: file.byte_size,
          size_human: ActiveSupport::NumberHelper.number_to_human_size(file.byte_size),
          created_at: format_datetime(file.created_at),
        }
      end,
    }
  end

  def format_activity_logs(marking)
    logs = marking.fraud_marking_logs.recent.limit(20)

    {
      total_entries: marking.fraud_marking_logs.count,
      recent_entries: logs.map do |log|
        {
          action: log.action,
          action_description: log.action_description,
          user: log.user_display,
          message: log.message,
          level: log.level,
          created_at: format_datetime(log.created_at),
          has_metadata: log.has_metadata?,
        }
      end,
    }
  end

  def format_datetime(datetime)
    return "" unless datetime

    if @options[:format_dates]
      datetime.strftime("%d/%m/%Y %H:%M:%S")
    else
      datetime.iso8601
    end
  end

  def truncate_text(text, length)
    return "" unless text

    if text.length > length
      "#{text[0..length-4]}..."
    else
      text
    end
  end

  def export_metadata
    {
      export_date: format_datetime(Time.current),
      export_type: "fraud_markings",
      total_records: @fraud_markings.count,
      options: @options,
      filters_applied: extract_filters_from_scope,
      exported_by: "system", # This could be enhanced to track actual user
      export_version: "1.0",
    }
  end

  def generate_summary
    markings = @fraud_markings.to_a # Load all records for summary

    {
      total_markings: markings.count,
      by_status: markings.group_by(&:status).transform_values(&:count),
      by_fraud_type: markings.group_by(&:fraud_type).transform_values(&:count),
      by_risk_level: markings.group_by(&:risk_level).transform_values(&:count),
      by_priority: markings.group_by(&:priority_level).transform_values(&:count),
      by_source: markings.group_by(&:created_by_source).transform_values(&:count),
      high_priority_count: markings.count(&:high_priority?),
      overdue_count: markings.count(&:overdue_for_response?),
      with_evidence: markings.count { |m| m.evidence_files.any? },
      sensitive_cases: markings.count(&:sensitive_case?),
      date_range: {
        earliest: markings.map(&:created_at).min,
        latest: markings.map(&:created_at).max,
      },
      average_approval_time: calculate_average_approval_time(markings),
      completion_rate: calculate_completion_rate(markings),
    }
  end

  def extract_filters_from_scope
    # This would analyze the ActiveRecord scope to extract applied filters
    # For now, return a simple representation
    {
      scope_class: @fraud_markings.klass.name,
      loaded: @fraud_markings.loaded?,
    }
  end

  def calculate_average_approval_time(markings)
    approved_markings = markings.select { |m| m.approved_at.present? }
    return 0 if approved_markings.empty?

    total_hours = approved_markings.sum do |marking|
      ((marking.approved_at - marking.created_at) / 1.hour).round(2)
    end

    (total_hours / approved_markings.count).round(2)
  end

  def calculate_completion_rate(markings)
    return 0 if markings.empty?

    completed = markings.count(&:final_state?)
    ((completed.to_f / markings.count) * 100).round(2)
  end
end

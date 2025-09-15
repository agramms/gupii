# Fraud Marking Evidence Service
# Manages file uploads, validation, and evidence handling for fraud markings
# Integrates with Active Storage for secure file management and compliance
class FraudMarkingEvidenceService
  include ActiveModel::Model

  # File type configurations
  ALLOWED_CONTENT_TYPES = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
    "text/csv",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  ].freeze

  ALLOWED_EXTENSIONS = %w[
    .jpg .jpeg .png .gif .webp
    .pdf
    .doc .docx
    .txt .csv
    .xls .xlsx
  ].freeze

  # Size limits from business rules
  MAX_FILE_SIZE = Jdpi::StatusCodes::BusinessRules::MAX_EVIDENCE_FILE_SIZE_MB.megabytes
  MAX_FILES = Jdpi::StatusCodes::BusinessRules::MAX_EVIDENCE_FILES

  attr_reader :fraud_marking, :files, :errors

  def initialize(fraud_marking:, files: [])
    @fraud_marking = fraud_marking
    @files = Array(files).compact
    @errors = []
  end

  # Main method to attach evidence files to fraud marking
  def attach_evidence_files
    return false unless validate_files

    begin
      Rails.logger.info "[FraudMarkingEvidenceService] Attaching #{@files.count} files to fraud marking #{@fraud_marking.short_id}"

      @files.each_with_index do |file, index|
        attach_single_file(file, index)
      end

      log_evidence_attachment

      Rails.logger.info "[FraudMarkingEvidenceService] Successfully attached #{@files.count} evidence files"
      true

    rescue StandardError => e
      Rails.logger.error "[FraudMarkingEvidenceService] Failed to attach files: #{e.message}"
      @errors << "Failed to attach evidence files: #{e.message}"
      false
    end
  end

  # Remove specific evidence file
  def remove_evidence_file(attachment_id, removed_by:)
    begin
      attachment = @fraud_marking.evidence_files.find(attachment_id)
      filename = attachment.filename.to_s

      Rails.logger.info "[FraudMarkingEvidenceService] Removing evidence file: #{filename}"

      attachment.purge

      # Log the removal
      FraudMarkingLog.create_for_action!(
        fraud_marking: @fraud_marking,
        action: "evidence_removed",
        user: removed_by,
        message: "Evidence file removed: #{filename}",
        filename: filename,
        removed_at: Time.current
      )

      Rails.logger.info "[FraudMarkingEvidenceService] Successfully removed evidence file: #{filename}"
      true

    rescue ActiveRecord::RecordNotFound
      @errors << "Evidence file not found"
      false
    rescue StandardError => e
      Rails.logger.error "[FraudMarkingEvidenceService] Failed to remove file: #{e.message}"
      @errors << "Failed to remove evidence file: #{e.message}"
      false
    end
  end

  # Get evidence files summary
  def evidence_summary
    files = @fraud_marking.evidence_files

    {
      total_files: files.count,
      total_size: files.sum(&:byte_size),
      file_types: files.group_by(&:content_type).transform_values(&:count),
      files: files.map do |file|
        {
          id: file.id,
          filename: file.filename.to_s,
          content_type: file.content_type,
          size: file.byte_size,
          size_human: ActiveSupport::NumberHelper.number_to_human_size(file.byte_size),
          created_at: file.created_at,
          download_url: Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
        }
      end
    }
  end

  # Validate evidence files for compliance
  def validate_evidence_integrity
    validation_results = {
      valid: true,
      issues: [],
      files_checked: 0,
      suspicious_files: []
    }

    @fraud_marking.evidence_files.each do |file|
      validation_results[:files_checked] += 1

      # Check file integrity
      unless file.blob.present?
        validation_results[:valid] = false
        validation_results[:issues] << "Missing file blob for: #{file.filename}"
        next
      end

      # Check file size consistency
      if file.byte_size != file.blob.byte_size
        validation_results[:valid] = false
        validation_results[:issues] << "Size mismatch for file: #{file.filename}"
      end

      # Check for suspicious file characteristics
      if check_suspicious_file(file)
        validation_results[:suspicious_files] << file.filename.to_s
      end

    rescue StandardError => e
      validation_results[:valid] = false
      validation_results[:issues] << "Validation error for #{file.filename}: #{e.message}"
    end

    validation_results
  end

  # Export evidence files as ZIP
  def export_evidence_as_zip
    require "zip"

    return nil if @fraud_marking.evidence_files.empty?

    zip_filename = "evidence_#{@fraud_marking.short_id}_#{Date.current.strftime('%Y%m%d')}.zip"
    zip_path = Rails.root.join("tmp", zip_filename)

    begin
      Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
        @fraud_marking.evidence_files.each_with_index do |file, index|
          # Download file content
          file_content = file.download

          # Create safe filename
          safe_filename = sanitize_filename("#{index + 1}_#{file.filename}")

          # Add to ZIP
          zipfile.get_output_stream(safe_filename) do |output_stream|
            output_stream.write file_content
          end
        end

        # Add metadata file
        metadata = generate_evidence_metadata
        zipfile.get_output_stream("evidence_metadata.json") do |output_stream|
          output_stream.write metadata.to_json
        end
      end

      Rails.logger.info "[FraudMarkingEvidenceService] Created evidence ZIP: #{zip_filename}"
      zip_path

    rescue StandardError => e
      Rails.logger.error "[FraudMarkingEvidenceService] Failed to create ZIP: #{e.message}"
      nil
    end
  end

  private

  def validate_files
    if @files.empty?
      @errors << "No files provided"
      return false
    end

    if @files.count > MAX_FILES
      @errors << "Too many files. Maximum #{MAX_FILES} files allowed."
      return false
    end

    # Check total existing files + new files
    existing_count = @fraud_marking.evidence_files.count
    if existing_count + @files.count > MAX_FILES
      @errors << "Total files would exceed maximum of #{MAX_FILES}. Currently have #{existing_count} files."
      return false
    end

    @files.each_with_index do |file, index|
      validate_single_file(file, index)
    end

    @errors.empty?
  end

  def validate_single_file(file, index)
    file_label = "File #{index + 1}"

    # Check if file is present and readable
    unless file.respond_to?(:read) && file.respond_to?(:original_filename)
      @errors << "#{file_label}: Invalid file object"
      return
    end

    # Check filename
    if file.original_filename.blank?
      @errors << "#{file_label}: Missing filename"
      return
    end

    filename = file.original_filename.to_s

    # Check file extension
    extension = File.extname(filename).downcase
    unless ALLOWED_EXTENSIONS.include?(extension)
      @errors << "#{file_label} (#{filename}): File type not allowed. Allowed types: #{ALLOWED_EXTENSIONS.join(', ')}"
    end

    # Check file size
    if file.size > MAX_FILE_SIZE
      max_size_mb = MAX_FILE_SIZE / 1.megabyte
      actual_size_mb = (file.size.to_f / 1.megabyte).round(2)
      @errors << "#{file_label} (#{filename}): File too large (#{actual_size_mb}MB). Maximum size: #{max_size_mb}MB"
    end

    # Check content type if available
    if file.respond_to?(:content_type) && file.content_type.present?
      unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
        @errors << "#{file_label} (#{filename}): Content type '#{file.content_type}' not allowed"
      end
    end

    # Check for empty files
    if file.size == 0
      @errors << "#{file_label} (#{filename}): File is empty"
    end

  rescue StandardError => e
    @errors << "#{file_label}: Error reading file - #{e.message}"
  end

  def attach_single_file(file, index)
    # Generate safe filename
    original_name = file.original_filename.to_s
    safe_filename = sanitize_filename(original_name)

    # Create blob with metadata
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: safe_filename,
      content_type: file.content_type || detect_content_type(safe_filename),
      metadata: {
        fraud_marking_id: @fraud_marking.id,
        original_filename: original_name,
        uploaded_at: Time.current,
        uploaded_by: "system", # This could be enhanced to track actual user
        file_index: index
      }
    )

    # Attach to fraud marking
    @fraud_marking.evidence_files.attach(blob)

    Rails.logger.debug "[FraudMarkingEvidenceService] Attached file: #{safe_filename} (#{ActiveSupport::NumberHelper.number_to_human_size(blob.byte_size)})"
  end

  def log_evidence_attachment
    filenames = @files.map(&:original_filename).join(", ")
    total_size = @files.sum(&:size)

    FraudMarkingLog.create_for_action!(
      fraud_marking: @fraud_marking,
      action: "evidence_added",
      user: "system", # This could be enhanced to track actual user
      message: "#{@files.count} evidence files attached: #{filenames}",
      file_count: @files.count,
      total_size: total_size,
      filenames: filenames,
      attached_at: Time.current
    )
  end

  def sanitize_filename(filename)
    # Remove dangerous characters and limit length
    safe_name = filename.gsub(/[^0-9A-Za-z.\-_]/, "_")
    safe_name = safe_name.truncate(100, omission: "")

    # Ensure we have a valid extension
    if File.extname(safe_name).blank?
      safe_name += ".txt"
    end

    safe_name
  end

  def detect_content_type(filename)
    extension = File.extname(filename).downcase

    case extension
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".png" then "image/png"
    when ".gif" then "image/gif"
    when ".pdf" then "application/pdf"
    when ".doc" then "application/msword"
    when ".docx" then "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    when ".txt" then "text/plain"
    when ".csv" then "text/csv"
    when ".xls" then "application/vnd.ms-excel"
    when ".xlsx" then "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else "application/octet-stream"
    end
  end

  def check_suspicious_file(file)
    # Basic suspicious file detection
    filename = file.filename.to_s.downcase

    # Check for executable extensions hidden in filename
    suspicious_patterns = [
      /\.exe\./,
      /\.bat\./,
      /\.scr\./,
      /\.vbs\./,
      /\.js\./,
      /script/,
      /<script/i
    ]

    suspicious_patterns.any? { |pattern| filename.match?(pattern) }
  end

  def generate_evidence_metadata
    {
      fraud_marking_id: @fraud_marking.id,
      fraud_marking_short_id: @fraud_marking.short_id,
      export_date: Time.current,
      total_files: @fraud_marking.evidence_files.count,
      files: @fraud_marking.evidence_files.map do |file|
        {
          filename: file.filename.to_s,
          content_type: file.content_type,
          size: file.byte_size,
          created_at: file.created_at,
          checksum: file.checksum
        }
      end,
      fraud_details: {
        pix_key: @fraud_marking.masked_pix_key_display,
        fraud_type: @fraud_marking.fraud_type,
        status: @fraud_marking.status,
        created_at: @fraud_marking.created_at
      }
    }
  end
end

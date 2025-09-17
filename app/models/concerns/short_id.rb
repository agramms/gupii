# frozen_string_literal: true

module ShortId
  extend ActiveSupport::Concern

  # Hashids-style configuration
  ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
  SALT = "gupii-pix-short-id" # Application-specific salt for consistent encoding

  # Generate a Hashids-style short ID from UUID for display purposes
  def short_id
    return nil if id.blank?

    begin
      require "hashids"
      hashids = Hashids.new(SALT, 8, ALPHABET)
      # Convert UUID to integer for Hashids encoding
      integer_from_uuid = uuid_to_integer(id.to_s)
      hashids.encode(integer_from_uuid)
    rescue LoadError
      # Fallback implementation if Hashids gem is not available
      short_id_fallback
    end
  end

  # Fallback implementation using custom base62 encoding
  def short_id_fallback
    return nil if id.blank?

    # Convert UUID to integer and encode with custom alphabet
    integer = uuid_to_integer(id.to_s)
    encode_integer(integer, ALPHABET)[0, 8]
  end

  # Generate a user-friendly display ID (primary method for UI)
  def display_id
    short_id
  end

  # Alternative short ID using CRC32 for even distribution
  def short_id_crc
    return nil if id.blank?

    require "zlib"
    crc = Zlib.crc32(id.to_s)
    encode_integer(crc, ALPHABET)[0, 8]
  end

  private

  # Convert UUID string to integer for encoding
  def uuid_to_integer(uuid_string)
    # Remove hyphens and convert hex to integer
    cleaned_uuid = uuid_string.delete("-")
    # Take first 16 hex characters to avoid integer overflow
    hex_part = cleaned_uuid[0, 16]
    hex_part.to_i(16)
  end

  # Custom base encoding function
  def encode_integer(number, alphabet)
    return alphabet[0] if number == 0

    base = alphabet.length
    encoded = ""

    while number > 0
      encoded = alphabet[number % base] + encoded
      number /= base
    end

    encoded
  end

  # Decode base-encoded string back to integer
  def decode_string(encoded, alphabet)
    base = alphabet.length
    decoded = 0

    encoded.each_char.with_index do |char, index|
      position = alphabet.index(char)
      return nil unless position

      power = encoded.length - index - 1
      decoded += position * (base ** power)
    end

    decoded
  end

  class_methods do
    # Find record by full UUID or short ID
    def find_by_any_id(identifier)
      return nil if identifier.blank?

      # If it looks like a full UUID, search directly
      if identifier.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        find_by(id: identifier)
      else
        # Search by short ID by checking all records
        # Note: For large datasets, consider adding a short_id column with index
        all.find { |record| record.display_id == identifier }
      end
    end

    # Efficient database search for short IDs
    def search_by_short_id(short_id)
      return none if short_id.blank?

      # For now, we'll need to check each record's generated short_id
      # In production, consider adding a database column for short_id with index
      ids = all.select { |record| record.display_id == short_id }.map(&:id)
      where(id: ids)
    end

    # Decode a short ID back to potential UUID patterns (for optimization)
    def decode_short_id(short_id)
      return [] if short_id.blank?

      # This is a helper method for future optimization
      # Could be used to reverse-engineer possible UUID patterns
      []
    end
  end
end

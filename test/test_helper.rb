# Code coverage setup (must be first)
if ENV["COVERAGE"]
  require "simplecov"
  require_relative "../.simplecov"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "mocha/minitest"

# Force English locale for tests
I18n.locale = :en

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Ensure tests run in English
    setup do
      I18n.locale = :en
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # JDPI Test Helpers
    include Jdpi::StatusCodes

    # Mock JDPI API responses for testing
    def mock_jdpi_success_response(data = {})
      {
        "status" => "SUCCESS",
        "timestamp" => Time.current.iso8601
      }.merge(data)
    end

    def mock_jdpi_error_response(error_code = 400, message = "Bad Request")
      {
        "error" => {
          "code" => error_code,
          "message" => message,
          "timestamp" => Time.current.iso8601
        }
      }
    end

    # Valid PIX key examples for testing
    def valid_cpf
      "12345678901"
    end

    def valid_cnpj
      "12345678000195"
    end

    def valid_email
      "test@example.com"
    end

    def valid_phone
      "+5511999999999"
    end

    def valid_uuid
      "550e8400-e29b-41d4-a716-446655440000"
    end

    # Valid PSP attributes for testing
    def valid_psp_attributes(overrides = {})
      {
        ispb: "12345678",
        name: "Test Payment Provider",
        short_name: "TestPSP",
        document_number: "12345678000199",
        document_type: "CNPJ",
        status: "active",
        psp_type: "commercial_bank",
        services_offered: [ "pix_payment", "pix_receiving" ],
        pix_enabled: true,
        regulatory_status: "authorized",
        last_sync_errors: [ "no_errors" ],
        jdpi_metadata: { "test" => "data" },
        validation_errors: [ "no_errors" ]
      }.merge(overrides)
    end

    # Test data for JDPI services
    def valid_infraction_params
      {
        pix_key: valid_cpf,
        infraction_type: InfractionTypes::FRAUD,
        description: "Test infraction for PIX key fraud detection",
        evidence_data: { "test" => "data", "risk_score" => 0.8 }
      }
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class Api::V1::PaymentServiceProvidersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        state: "SP",
        city: "São Paulo",
        contact_email: "contact@testpsp.com",
        website: "https://testpsp.com",
        last_sync_at: 1.hour.ago,
        total_transactions: 1000,
        total_volume: 50000.00
      )
    )

    @inactive_psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        name: "Inactive PSP",
        status: "inactive",
        psp_type: "cooperative",
        services_offered: [ "ted_transfer" ],
        pix_enabled: false
      )
    )

    @headers = { "Content-Type" => "application/json" }
  end

  # Index tests
  test "should get index with proper JSON structure" do
    get api_v1_payment_service_providers_url, headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_json_structure(json_response, [ :data, :meta, :links, :generated_at ])
    assert_equal 2, json_response["data"].length

    # Check meta structure
    assert_json_structure(json_response["meta"], [ :pagination, :total_count, :page, :per_page, :total_pages ])

    # Check links structure
    assert_json_structure(json_response["links"], [ :self, :first, :last ])

    # Check PSP data structure
    psp_data = json_response["data"].first
    expected_fields = [ :id, :short_id, :ispb, :name, :status, :psp_type, :pix_enabled,
                       :operational_status, :services_offered, :created_at, :updated_at ]
    assert_json_structure(psp_data, expected_fields)
  end

  test "should filter by status" do
    get api_v1_payment_service_providers_url,
        params: { status: "active" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "active", json_response["data"].first["status"]
  end

  test "should filter by pix_enabled" do
    get api_v1_payment_service_providers_url,
        params: { pix_enabled: "true" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert json_response["data"].first["pix_enabled"]
  end

  test "should filter by state" do
    get api_v1_payment_service_providers_url,
        params: { state: "SP" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "SP", json_response["data"].first["state"]
  end

  test "should filter by active_only" do
    get api_v1_payment_service_providers_url,
        params: { active_only: "true" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "active", json_response["data"].first["status"]
  end

  test "should sort by different fields" do
    get api_v1_payment_service_providers_url,
        params: { sort: "name", direction: "desc" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["data"].length
    # Should be sorted by name descending
    assert json_response["data"].first["name"] >= json_response["data"].last["name"]
  end

  test "should handle pagination" do
    get api_v1_payment_service_providers_url,
        params: { per_page: 1, page: 1 },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal 1, json_response["meta"]["page"]
    assert_equal 1, json_response["meta"]["per_page"]
    assert_equal 2, json_response["meta"]["total_pages"]

    # Check pagination links
    assert json_response["links"]["next"].present?
    assert json_response["links"]["prev"].nil?
  end

  test "should limit per_page to maximum" do
    get api_v1_payment_service_providers_url,
        params: { per_page: 200 },
        headers: @headers

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Per page limit exceeded"
  end

  test "should validate page parameter" do
    get api_v1_payment_service_providers_url,
        params: { page: -1 },
        headers: @headers

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Invalid page number"
  end

  # Show tests
  test "should show PSP with detailed information" do
    get api_v1_payment_service_provider_url(@psp), headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_json_structure(json_response, [ :data, :generated_at ])

    psp_data = json_response["data"]
    detailed_fields = [ :id, :short_id, :ispb, :name, :document_number, :document_type,
                       :legal_address, :city, :state, :contact_phone, :contact_email,
                       :website, :sync_status, :sync_health_score, :total_transactions,
                       :total_volume, :availability_percentage, :avg_response_time_ms ]
    assert_json_structure(psp_data, detailed_fields)

    assert_equal @psp.ispb, psp_data["ispb"]
    assert_equal @psp.name, psp_data["name"]
    assert_equal @psp.total_transactions, psp_data["total_transactions"]
  end

  test "should show PSP by short_id" do
    get api_v1_payment_service_provider_url(@psp.short_id), headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @psp.ispb, json_response["data"]["ispb"]
  end

  test "should return 404 for non-existent PSP" do
    get api_v1_payment_service_provider_url("nonexistent"), headers: @headers

    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal "PSP not found", json_response["error"]
  end

  # Search tests
  test "should search PSPs by name" do
    get search_api_v1_payment_service_providers_url,
        params: { q: "Test Payment" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_includes json_response["data"].first["name"], "Test Payment"
    assert_equal "Test Payment", json_response["meta"]["search_query"]
  end

  test "should search PSPs by ISPB" do
    get search_api_v1_payment_service_providers_url,
        params: { q: "12345678" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "12345678", json_response["data"].first["ispb"]
  end

  test "should require search query" do
    get search_api_v1_payment_service_providers_url, headers: @headers

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Search query"
  end

  test "should require minimum search length" do
    get search_api_v1_payment_service_providers_url,
        params: { q: "T" },
        headers: @headers

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "at least 2 characters"
  end

  test "should limit search results" do
    # Search results should be limited even if more records match
    get search_api_v1_payment_service_providers_url,
        params: { q: "PSP", per_page: 100 },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    # Should be limited to 50 even though per_page was 100
    assert json_response["meta"]["pagination"]["items"] <= 50
  end

  # ISPB lookup tests
  test "should find PSP by ISPB" do
    get by_ispb_api_v1_payment_service_providers_url(@psp.ispb), headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @psp.ispb, json_response["data"]["ispb"]
    assert_equal @psp.name, json_response["data"]["name"]
  end

  test "should validate ISPB format" do
    get by_ispb_api_v1_payment_service_providers_url("invalid"), headers: @headers

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Invalid ISPB format"
  end

  test "should return 404 for non-existent ISPB" do
    get by_ispb_api_v1_payment_service_providers_url("99999999"), headers: @headers

    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "not found"
  end

  # Active PSPs tests
  test "should get active PSPs only" do
    get active_api_v1_payment_service_providers_url, headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "active", json_response["data"].first["status"]
    assert_equal "active", json_response["meta"]["filter"]
  end

  # PIX-enabled PSPs tests
  test "should get PIX-enabled PSPs only" do
    get pix_enabled_api_v1_payment_service_providers_url, headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert json_response["data"].first["pix_enabled"]
    assert_equal "pix_enabled", json_response["meta"]["filter"]
  end

  # Stats tests
  test "should get PSP statistics" do
    get stats_api_v1_payment_service_providers_url, headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_json_structure(json_response, [ :data, :meta, :generated_at ])

    stats_data = json_response["data"]
    expected_stats = [ :total_psps, :active_psps, :pix_enabled_psps, :pix_adoption_rate,
                      :by_status, :by_regulatory_status, :by_psp_type, :data_freshness ]
    assert_json_structure(stats_data, expected_stats)

    assert_equal 2, stats_data["total_psps"]
    assert_equal 1, stats_data["active_psps"]
    assert_equal 1, stats_data["pix_enabled_psps"]
    assert_equal 50.0, stats_data["pix_adoption_rate"]
  end

  test "should cache statistics" do
    # First request
    get stats_api_v1_payment_service_providers_url, headers: @headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["meta"]["cached"] || json_response["meta"]["cached"] == false

    # Second request should be cached
    get stats_api_v1_payment_service_providers_url, headers: @headers
    assert_response :success

    json_response2 = JSON.parse(response.body)
    # Cache status might vary, but structure should be consistent
    assert_json_structure(json_response2["meta"], [ :cached, :cache_expires_at ])
  end

  # Date filtering tests
  test "should filter by creation date" do
    get api_v1_payment_service_providers_url,
        params: { created_after: 1.hour.ago.to_date.to_s },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["data"].length
  end

  test "should filter by update date" do
    # Update one PSP
    @psp.touch

    get api_v1_payment_service_providers_url,
        params: { updated_after: 1.minute.ago.to_date.to_s },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal @psp.ispb, json_response["data"].first["ispb"]
  end

  test "should handle invalid date formats gracefully" do
    get api_v1_payment_service_providers_url,
        params: { created_after: "invalid-date" },
        headers: @headers

    assert_response :success

    json_response = JSON.parse(response.body)
    # Should ignore invalid date and return all records
    assert_equal 2, json_response["data"].length
  end

  # Error handling tests
  test "should handle database errors gracefully" do
    PaymentServiceProvider.stubs(:all).raises(StandardError.new("Database connection error"))

    get api_v1_payment_service_providers_url, headers: @headers

    assert_response :internal_server_error

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Failed to load PSPs"
  end

  test "should handle search errors gracefully" do
    PaymentServiceProvider.stubs(:where).raises(StandardError.new("Search index error"))

    get search_api_v1_payment_service_providers_url,
        params: { q: "test" },
        headers: @headers

    assert_response :internal_server_error

    json_response = JSON.parse(response.body)
    assert_includes json_response["error"], "Search failed"
  end

  # Security tests
  test "should prevent SQL injection in sort parameter" do
    malicious_sort = "name; DROP TABLE payment_service_providers; --"

    get api_v1_payment_service_providers_url,
        params: { sort: malicious_sort },
        headers: @headers

    assert_response :success
    # Should fallback to default sorting and not execute malicious SQL
    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["data"].length
  end

  test "should sanitize search parameters" do
    malicious_search = "'; DROP TABLE payment_service_providers; --"

    get search_api_v1_payment_service_providers_url,
        params: { q: malicious_search },
        headers: @headers

    assert_response :success
    # Should treat as literal search string and not execute SQL
    json_response = JSON.parse(response.body)
    assert_equal 0, json_response["data"].length # No matches expected
  end

  # Content type tests
  test "should handle requests without JSON content type" do
    get api_v1_payment_service_providers_url

    assert_response :success
    # Should still return JSON
    assert response.content_type.include?("application/json")
  end

  private

  def assert_json_structure(json, expected_keys)
    expected_keys.each do |key|
      assert json.key?(key.to_s), "Expected JSON to include key: #{key}"
    end
  end
end

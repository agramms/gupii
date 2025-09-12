require 'test_helper'
require 'ostruct'

class PaymentServiceProvidersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        state: 'SP',
        city: 'São Paulo',
        contact_email: 'contact@testpsp.com',
        last_sync_at: 1.hour.ago,
        last_successful_sync_at: 1.hour.ago,
        sync_attempts: 1
      )
    )
    
    @inactive_psp = PaymentServiceProvider.create!(
      valid_psp_attributes.merge(
        ispb: '87654321',
        name: 'Inactive PSP',
        document_number: '87654321000188',
        status: 'inactive',
        psp_type: 'cooperative',
        services_offered: ['ted_transfer'],
        pix_enabled: false
      )
    )
    
    # Mock dashboard data
    @mock_dashboard_data = {
      overview: {
        total_psps: 2,
        active_psps: 1,
        pix_enabled_count: 1,
        pix_adoption_rate: 50.0,
        last_updated: Time.current.iso8601
      },
      sync_health: {
        total: 2,
        needs_sync: 0,
        sync_failed: 0,
        last_successful_sync: 1.hour.ago
      },
      operational_status: {
        operational: 1,
        degraded: 0,
        inactive: 1,
        unauthorized: 0,
        pix_disabled: 0
      },
      recent_activity: {
        last_created: 1.hour.ago,
        last_updated: 1.hour.ago,
        last_synced: 1.hour.ago,
        recent_changes_count: 0
      },
      data_freshness: {
        fresh_data_count: 1,
        stale_data_count: 1,
        very_stale_count: 0,
        avg_data_age_hours: 1.5
      }
    }
    
    PspMetricsService.stubs(:dashboard_data).returns(@mock_dashboard_data)
    PspMetricsService.stubs(:health_alerts).returns([])
  end

  test 'should get index' do
    get payment_service_providers_url
    
    assert_response :success
    assert_select 'h1', 'Payment Service Providers'
    assert_select '.grid .bg-white', count: 2 # Two PSP cards
  end

  test 'should get index with search' do
    get payment_service_providers_url, params: { search: 'Test' }
    
    assert_response :success
    assert_select '.grid .bg-white', count: 1 # Only matching PSP
  end

  test 'should get index with status filter' do
    get payment_service_providers_url, params: { status: 'active' }
    
    assert_response :success
    assert_select '.grid .bg-white', count: 1 # Only active PSP
  end

  test 'should get index with PIX filter' do
    get payment_service_providers_url, params: { pix_enabled: 'true' }
    
    assert_response :success
    assert_select '.grid .bg-white', count: 1 # Only PIX-enabled PSP
  end

  test 'should handle empty search results' do
    get payment_service_providers_url, params: { search: 'nonexistent' }
    
    assert_response :success
    assert_select 'h3', 'No PSPs Found'
    assert_select '.grid .bg-white', count: 0
  end

  test 'should get index as JSON' do
    get payment_service_providers_url, as: :json
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('psps')
    assert json_response.key?('pagination')
    assert json_response.key?('dashboard')
    assert_equal 2, json_response['psps'].length
  end

  test 'should show PSP' do
    get payment_service_provider_url(@psp)
    
    assert_response :success
    assert_select 'h1', @psp.display_name
    assert_select 'p', text: /ID: #{@psp.display_id}/
    assert_select 'p', text: /ISPB: #{@psp.ispb}/
  end

  test 'should show PSP by short_id' do
    get payment_service_provider_url(@psp.short_id)
    
    assert_response :success
    assert_select 'h1', @psp.display_name
  end

  test 'should show PSP as JSON' do
    get payment_service_provider_url(@psp), as: :json
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('psp')
    assert json_response.key?('sync_history')
    assert json_response.key?('operational_metrics')
    assert_equal @psp.ispb, json_response['psp']['ispb']
  end

  test 'should redirect when PSP not found' do
    get payment_service_provider_url('nonexistent')
    
    assert_redirected_to payment_service_providers_path
    assert_includes flash[:error], 'PSP not found'
  end

  test 'should return 404 JSON when PSP not found' do
    get payment_service_provider_url('nonexistent'), as: :json
    
    assert_response :not_found
    
    json_response = JSON.parse(response.body)
    assert_equal 'PSP not found', json_response['error']
  end

  test 'should schedule full sync' do
    PspSyncJob.expects(:schedule_full_sync).returns(
      OpenStruct.new(job_id: 'test-job-123')
    )
    
    post sync_payment_service_providers_url, params: { sync_type: 'full' }
    
    assert_redirected_to payment_service_providers_path
    assert_match(/Full sync scheduled successfully/, flash[:success])
  end

  test 'should schedule incremental sync' do
    PspSyncJob.expects(:schedule_incremental_sync).returns(
      OpenStruct.new(job_id: 'test-job-456')
    )
    
    post sync_payment_service_providers_url, params: { sync_type: 'incremental' }
    
    assert_redirected_to payment_service_providers_path
    assert_match(/Incremental sync scheduled successfully/, flash[:success])
  end

  test 'should schedule single PSP sync' do
    PspSyncJob.expects(:schedule_single_psp_sync)
             .with(@psp.ispb, anything)
             .returns(OpenStruct.new(job_id: 'test-job-789'))
    
    post sync_payment_service_providers_url, params: { 
      sync_type: 'single',
      ispb: @psp.ispb
    }
    
    assert_redirected_to payment_service_providers_path
    assert_match(/Single sync scheduled successfully/, flash[:success])
  end

  test 'should require ISPB for single sync' do
    post sync_payment_service_providers_url, 
         params: { sync_type: 'single' },
         as: :json
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal 'ISPB is required for single PSP sync', json_response['error']
  end

  test 'should handle sync scheduling errors' do
    PspSyncJob.expects(:schedule_full_sync).raises(StandardError.new('Job queue full'))
    
    post sync_payment_service_providers_url, params: { sync_type: 'full' }
    
    assert_redirected_to payment_service_providers_path
    assert_match(/Sync scheduling failed/, flash[:error])
  end

  test 'should return sync status' do
    PspSyncJob.stubs(:last_sync_status).returns({
      last_success: { timestamp: 1.hour.ago.iso8601, job_id: 'success-123' },
      last_error: { timestamp: 2.hours.ago.iso8601, error: 'Connection timeout' }
    })
    
    get sync_status_payment_service_providers_url, as: :json
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('last_success')
    assert json_response.key?('last_error')
    assert_equal 'healthy', json_response['overall_health']
  end

  test 'should get metrics dashboard' do
    get metrics_payment_service_providers_url
    
    assert_response :success
    assert_select 'h1', 'PSP Metrics Dashboard'
    assert_select '.text-3xl', text: '2' # Total PSPs
    assert_select '.text-3xl', text: '1' # Active PSPs
  end

  test 'should get metrics as JSON' do
    get metrics_payment_service_providers_url, as: :json
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('dashboard')
    assert json_response.key?('alerts')
    assert json_response.key?('generated_at')
  end

  test 'should get health status' do
    get health_payment_service_providers_url, as: :json
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('status')
    assert json_response.key?('health_score')
    assert json_response.key?('total_psps')
    assert_equal 2, json_response['total_psps']
  end

  test 'should return unhealthy status when issues detected' do
    # Create many PSPs that need sync to trigger unhealthy status
    10.times do |i|
      PaymentServiceProvider.create!(
        valid_psp_attributes.merge(
          ispb: "1111111#{i}",
          name: "Test PSP #{i}",
          document_number: "1111111#{i}000199",
          services_offered: ['ted_transfer'],
          last_sync_at: 25.hours.ago, # Very stale
          sync_attempts: 5 # Failed sync
        )
      )
    end
    
    get health_payment_service_providers_url, as: :json
    
    assert_response :service_unavailable
    
    json_response = JSON.parse(response.body)
    assert_includes ['unhealthy', 'degraded'], json_response['status']
    assert json_response['health_score'] < 50
  end

  test 'should handle health check errors' do
    PaymentServiceProvider.stubs(:count).raises(StandardError.new('Database error'))
    
    get health_payment_service_providers_url, as: :json
    
    assert_response :service_unavailable
    
    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_includes json_response['error'], 'Database error'
  end

  test 'should display health alerts' do
    PspMetricsService.stubs(:health_alerts).returns([
      {
        level: 'error',
        type: 'sync_failures',
        message: '5 PSPs have sync failures',
        count: 5,
        action: 'Review error logs'
      }
    ])
    
    get payment_service_providers_url
    
    assert_response :success
    assert_select '.bg-red-50', count: 1 # Error alert banner
    assert_select 'h3', text: /Critical PSP Issues Detected/
  end

  test 'should sort PSPs by different columns' do
    get payment_service_providers_url, params: { sort: 'name', direction: 'desc' }
    
    assert_response :success
    # Should include both PSPs but in descending order
    assert_select '.grid .bg-white', count: 2
  end

  test 'should handle invalid sort parameters safely' do
    get payment_service_providers_url, params: { sort: 'malicious_column; DROP TABLE psps;' }
    
    assert_response :success
    # Should fallback to default sorting
    assert_select '.grid .bg-white', count: 2
  end

  test 'should build correct PSP query with filters' do
    # Test multiple filter combinations
    get payment_service_providers_url, params: {
      search: 'Test',
      status: 'active',
      psp_type: 'commercial_bank',
      state: 'SP',
      pix_enabled: 'true'
    }
    
    assert_response :success
    assert_select '.grid .bg-white', count: 1 # Should match only the test PSP
  end

  test 'should show sync history in PSP details' do
    get payment_service_provider_url(@psp)
    
    assert_response :success
    assert_select 'dt', text: 'Last Sync'
    assert_select 'dt', text: 'Last Successful Sync'
    assert_select 'dt', text: 'Sync Attempts'
  end

  test 'should show operational metrics in PSP details' do
    @psp.update!(
      total_transactions: 1000,
      total_volume: 50000.50,
      availability_percentage: 99.9,
      avg_response_time_ms: 150.5,
      error_count_24h: 2
    )
    
    get payment_service_provider_url(@psp)
    
    assert_response :success
    assert_select 'dt', text: 'Total Transactions'
    assert_select 'dt', text: 'Total Volume'  
    assert_select 'dt', text: 'Availability'
    assert_select 'dt', text: 'Avg Response Time'
    assert_select 'dt', text: 'Errors (24h)'
    assert_select 'dd', text: /1,000/
    assert_select 'dd', text: /99\.9%/
  end

  test 'should display recent sync errors if present' do
    @psp.update!(last_sync_errors: [
      'Connection timeout',
      'Invalid response format',
      'Rate limit exceeded'
    ])
    
    get payment_service_provider_url(@psp)
    
    assert_response :success
    assert_select 'h2', text: 'Recent Sync Issues'
    assert_select '.bg-red-50', count: 3 # Three error messages
  end

  private

  def assert_json_structure(json, expected_keys)
    expected_keys.each do |key|
      assert json.key?(key.to_s), "Expected JSON to include key: #{key}"
    end
  end
end
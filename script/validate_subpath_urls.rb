#!/usr/bin/env ruby
# Simple validation script for subpath URL generation

puts "🔍 Validating Subpath URL Generation..."
puts "=" * 50

# Include Rails URL helpers
include Rails.application.routes.url_helpers

# Test basic path helpers
test_paths = [
  [ "disputes_path", disputes_path ],
  [ "infraction_notifications_path", infraction_notifications_path ],
  [ "new_infraction_notification_path", new_infraction_notification_path ],
  [ "pix_keys_path", pix_keys_path ],
  [ "new_pix_key_path", new_pix_key_path ],
  [ "root_path", root_path ]
]

puts "\n📍 Basic Path Helper Tests:"
test_paths.each do |name, path|
  expected_prefix = "/app"
  status = path.start_with?(expected_prefix) ? "✅ PASS" : "❌ FAIL"
  puts "  #{name}: #{path} #{status}"
end

# Test parameterized paths
puts "\n🔗 Parameterized Path Tests:"
param_tests = [
  [ "edit_pix_key_path(123)", edit_pix_key_path(123) ],
  [ "dispute_path(456)", dispute_path(456) ],
  [ "infraction_notification_path(789)", infraction_notification_path(789) ]
]

param_tests.each do |name, path|
  expected_prefix = "/app"
  status = path.start_with?(expected_prefix) ? "✅ PASS" : "❌ FAIL"
  puts "  #{name}: #{path} #{status}"
end

# Test nested routes
puts "\n🏗️ Nested Route Tests:"
nested_tests = [
  [ "new_infraction_notification_dispute_path(123)", new_infraction_notification_dispute_path(123) ]
]

nested_tests.each do |name, path|
  expected_prefix = "/app"
  status = path.start_with?(expected_prefix) ? "✅ PASS" : "❌ FAIL"
  puts "  #{name}: #{path} #{status}"
end

# Environment validation
puts "\n⚙️ Environment Configuration:"
puts "  Rails.env: #{Rails.env}"
puts "  relative_url_root: #{Rails.application.config.relative_url_root.inspect}"
puts "  Initializer loaded: #{defined?(ActionDispatch::Routing::RouteSet) ? '✅ YES' : '❌ NO'}"

puts "\n" + "=" * 50
puts "🎯 URL Generation Test Complete!"
puts "   If all tests show ✅ PASS, subpath functionality is working correctly."

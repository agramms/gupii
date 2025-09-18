# frozen_string_literal: true

# SimpleCov configuration for Gupii PIX Integration
SimpleCov.start 'rails' do
  # Enable branch coverage for more detailed metrics
  enable_coverage :branch

  # Add groups for better organization
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Libraries", "lib"

  # Add filters to exclude certain files from coverage
  add_filter "/bin/"
  add_filter "/db/"
  add_filter "/spec/"
  add_filter "/test/"
  add_filter "/tmp/"
  add_filter "/vendor/"
  add_filter "/config/"
  add_filter "app/channels/application_cable/"

  # Exclude generated files and boilerplate
  add_filter "app/controllers/application_controller.rb" do |source_file|
    # Only exclude if it's mostly boilerplate (less than 10 lines of actual code)
    source_file.lines.count < 10
  end

  # Set minimum coverage thresholds
  # minimum_coverage 10 # Temporary Changes
  # minimum_coverage_by_file 10 # Temporary Changes

  # Configure formatters for CI integration
  if ENV['COVERAGE']
    require 'simplecov-lcov'

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      c.single_report_path = 'coverage/lcov.info'
    end

    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter,
    ])
  end

  # Track files even if they're not required during test run
  track_files '{app,lib}/**/*.rb'
end

#!/usr/bin/env ruby
# Adds the iosAppTests unit-test target + a shared scheme with code coverage.
require 'xcodeproj'

project_path = File.join(__dir__, '..', 'iosApp', 'iosApp.xcodeproj')
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'iosApp' } or abort 'iosApp target not found'

if project.targets.any? { |t| t.name == 'iosAppTests' }
  abort 'iosAppTests already exists'
end

test = project.new_target(:unit_test_bundle, 'iosAppTests', :ios, '17.0')
test.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ticktrust.siwa.tests'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/iosApp.app/iosApp'
  s['BUNDLE_LOADER'] = '$(TEST_HOST)'
  s['DEVELOPMENT_TEAM'] = 'NBTYA5Q847'
  s['CODE_SIGN_STYLE'] = 'Automatic'
end

group = project.main_group.new_group('iosAppTests', 'iosAppTests')
ref = group.new_reference('ModelsTests.swift')
test.add_file_references([ref])
test.add_dependency(app)

# Shared scheme that builds the app and runs the tests with coverage on.
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(test)
scheme.set_launch_target(app)
scheme.test_action.code_coverage_enabled = true
scheme.save_as(project_path, 'iosApp', true)

project.save
puts "OK. targets: #{project.targets.map(&:name).join(', ')}"

#!/usr/bin/env ruby
# Adds the TickTrustMonitor DeviceActivityMonitor app-extension target to the
# iOS project and wires it up (sources, embed, dependency, shared file).
require 'xcodeproj'

project_path = File.join(__dir__, '..', 'iosApp', 'iosApp.xcodeproj')
project = Xcodeproj::Project.open(project_path)

app = project.targets.find { |t| t.name == 'iosApp' } or abort 'iosApp target not found'

if project.targets.any? { |t| t.name == 'TickTrustMonitor' }
  abort 'TickTrustMonitor target already exists — aborting to stay idempotent'
end

# 1) New app-extension target
ext = project.new_target(:app_extension, 'TickTrustMonitor', :ios, '17.0')

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ticktrust.siwa.monitor'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'TickTrustMonitor/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'TickTrustMonitor/TickTrustMonitor.entitlements'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = 'NBTYA5Q847'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['SKIP_INSTALL'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# 2) Group + source files for the extension
ext_group = project.main_group.new_group('TickTrustMonitor', 'TickTrustMonitor')
ext_swift = ext_group.new_reference('DeviceActivityMonitorExtension.swift')
ext_group.new_reference('Info.plist')
ext_group.new_reference('TickTrustMonitor.entitlements')
ext.add_file_references([ext_swift])

# 3) Shared MonitorStore.swift — add to project (Agent group) and both targets
agent_group = project.main_group.recursive_children.find do |g|
  g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == 'Agent'
end || project.main_group['iosApp']
shared_ref = agent_group.new_reference('MonitorStore.swift')
app.add_file_references([shared_ref])
ext.add_file_references([shared_ref])

# 4) Embed the extension into the app + depend on it
app.add_dependency(ext)
embed = app.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts 'OK: TickTrustMonitor target added.'
puts "targets: #{project.targets.map(&:name).join(', ')}"

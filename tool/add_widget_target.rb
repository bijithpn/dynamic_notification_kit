#!/usr/bin/env ruby
# Usage: add_widget_target.rb <path/to/Runner.xcodeproj> <ExtensionName> <ios_deployment_target>
# Idempotent: exits 0 without changes if the target already exists.
require 'xcodeproj'

proj_path, name, ios = ARGV
abort 'usage: add_widget_target.rb <xcodeproj> <name> <ios>' unless proj_path && name && ios

project = Xcodeproj::Project.open(proj_path)
exit 0 if project.targets.any? { |t| t.name == name }

app = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'
dir = File.join(File.dirname(proj_path), name)
abort "#{dir} missing" unless Dir.exist?(dir)

ext = project.new_target(:app_extension, name, :ios, ios)
app_bundle_id = app.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']

group = project.main_group.find_subpath(name, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(name)
Dir.children(dir).sort.each do |f|
  ref = group.new_file(f)
  ext.add_file_references([ref]) if f.end_with?('.swift')
end

# DeliveryAttributes.swift must also be compiled into the app so both targets
# share the same ActivityAttributes type.
attrs = group.files.find { |f| f.path == 'DeliveryAttributes.swift' }
app.add_file_references([attrs]) if attrs

%w[WidgetKit SwiftUI ActivityKit].each do |fw|
  ext.add_system_framework(fw)
end

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{app_bundle_id}.#{name}"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{name}/Info.plist"
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = ios
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
end

# Runner has Debug/Release/Profile; mirror Profile for the extension.
app.build_configurations.each do |ac|
  next if ext.build_configurations.any? { |c| c.name == ac.name }
  copy = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  copy.name = ac.name
  copy.build_settings = ext.build_configurations.first.build_settings.dup
  ext.build_configuration_list.build_configurations << copy
end

# Embed the extension in the app, before "Thin Binary" to avoid a build cycle.
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
thin = app.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  app.build_phases.delete(embed)
  app.build_phases.insert(app.build_phases.index(thin), embed)
end
app.add_dependency(ext)

project.save
puts "added #{name}"

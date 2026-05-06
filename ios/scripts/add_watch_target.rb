#!/usr/bin/env ruby
# frozen_string_literal: true
#
# add_watch_target.rb — Adds MajuRunWatch watchOS target to Runner.xcodeproj
# Idempotent: safe to run on every build.

require 'xcodeproj'

PROJECT_PATH     = File.expand_path('../Runner.xcodeproj', __dir__)
WATCH_NAME       = 'MajuRunWatch'
WATCH_BUNDLE_ID  = 'com.majurun.app.watchkitapp'
WATCH_SOURCE_DIR = 'MajuRunWatch Watch App'
TEAM_ID          = ENV.fetch('TEAM_ID', 'RG52X42W22')

project = Xcodeproj::Project.open(PROJECT_PATH)

# ── Idempotency ──────────────────────────────────────────────────────────────
if project.targets.any? { |t| t.name == WATCH_NAME }
  puts "✅ '#{WATCH_NAME}' already exists — skipping."
  exit 0
end

puts "➕ Adding watchOS target '#{WATCH_NAME}'..."

# ── Create target manually (avoid xcodeproj platform bugs) ──────────────────
watch_target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
watch_target.name                   = WATCH_NAME
watch_target.product_type           = 'com.apple.product-type.application'
watch_target.product_name           = WATCH_NAME
watch_target.build_configuration_list = project.add_build_configuration_list_for_target(watch_target)

# Product reference
product_ref = project.products_group.new_reference("#{WATCH_NAME}.app")
product_ref.explicit_file_type      = 'wrapper.application'
product_ref.include_in_index        = '0'
product_ref.source_tree             = 'BUILT_PRODUCTS_DIR'
product_ref.path                    = "#{WATCH_NAME}.app"
watch_target.product_reference      = product_ref

# Add to project targets
project.targets << watch_target

# ── Build phases ─────────────────────────────────────────────────────────────
sources_phase   = project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
frameworks_phase = project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
resources_phase = project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)

watch_target.build_phases << sources_phase
watch_target.build_phases << frameworks_phase
watch_target.build_phases << resources_phase

# ── Build configurations ─────────────────────────────────────────────────────
common_settings = {
  'PRODUCT_NAME'                             => WATCH_NAME,
  'PRODUCT_BUNDLE_IDENTIFIER'                => WATCH_BUNDLE_ID,
  'SDKROOT'                                  => 'watchos',
  'TARGETED_DEVICE_FAMILY'                   => '4',
  'WATCHOS_DEPLOYMENT_TARGET'                => '8.0',
  'SWIFT_VERSION'                            => '5.0',
  'INFOPLIST_FILE'                           => "#{WATCH_SOURCE_DIR}/Info.plist",
  'CODE_SIGN_STYLE'                          => 'Manual',
  'DEVELOPMENT_TEAM'                         => TEAM_ID,
  'MARKETING_VERSION'                        => '$(FLUTTER_BUILD_NAME)',
  'CURRENT_PROJECT_VERSION'                  => '$(FLUTTER_BUILD_NUMBER)',
  'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'    => 'YES',
  'ENABLE_BITCODE'                           => 'NO',
  'LD_RUNPATH_SEARCH_PATHS'                  => '$(inherited) @executable_path/Frameworks',
  'SWIFT_COMPILATION_MODE'                   => 'wholemodule',
}

watch_target.build_configurations.each do |config|
  config.build_settings.merge!(common_settings)
  if config.name == 'Release'
    config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  else
    config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  end
end

# ── Source file group ────────────────────────────────────────────────────────
watch_group = project.main_group.find_subpath(WATCH_SOURCE_DIR, true)
watch_group.set_source_tree('<group>')
watch_group.set_path(WATCH_SOURCE_DIR)

%w[MajuRunWatchApp.swift WatchSessionManager.swift ContentView.swift].each do |f|
  ref = watch_group.new_reference(f)
  ref.last_known_file_type = 'sourcecode.swift'
  build_file = sources_phase.add_file_reference(ref)
  build_file
end

watch_group.new_reference('Info.plist')

# ── WatchConnectivity framework ──────────────────────────────────────────────
fw_group = project.frameworks_group
wc_ref   = fw_group.new_reference('WatchConnectivity.framework')
wc_ref.name        = 'WatchConnectivity.framework'
wc_ref.path        = 'System/Library/Frameworks/WatchConnectivity.framework'
wc_ref.source_tree = 'SDKROOT'
wc_ref.last_known_file_type = 'wrapper.framework'
frameworks_phase.add_file_reference(wc_ref)

# ── Embed watch content in Runner ────────────────────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }
abort('❌ Runner target not found') unless runner_target

embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name                = 'Embed Watch Content'
embed_phase.dst_subfolder_spec  = '16'   # Watch application folder
embed_phase.dst_path            = '$(CONTENTS_FOLDER_PATH)/Watch'
runner_target.build_phases << embed_phase

embed_file = embed_phase.add_file_reference(product_ref)
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ── Save ─────────────────────────────────────────────────────────────────────
project.save

puts "✅ Watch target added successfully."
puts "   Bundle ID : #{WATCH_BUNDLE_ID}"
puts "   Source dir: ios/#{WATCH_SOURCE_DIR}"

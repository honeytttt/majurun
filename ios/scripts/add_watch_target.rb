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

# ── Create target via new_target so xcodeproj sets platform/SDK/WatchKit ────
# new_target(:application, name, :watchos, deployment_target) correctly sets:
#   SDKROOT=watchos, TARGETED_DEVICE_FAMILY=4, WATCHOS_DEPLOYMENT_TARGET,
#   and links WatchKit.framework automatically.
watch_target = project.new_target(:application, WATCH_NAME, :watchos, '8.0')

# Fix product reference — new_target leaves path empty which causes
# "Multiple commands produce '.../.app'" when Xcode builds the scheme.
watch_target.product_reference.path = "#{WATCH_NAME}.app"
watch_target.product_reference.name = WATCH_NAME

# ── Extra build settings on top of what new_target generated ─────────────────
watch_target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'             => WATCH_BUNDLE_ID,
    'SWIFT_VERSION'                         => '5.0',
    'INFOPLIST_FILE'                        => "#{WATCH_SOURCE_DIR}/Info.plist",
    'CODE_SIGN_ENTITLEMENTS'                => "#{WATCH_SOURCE_DIR}/MajuRunWatch.entitlements",
    'CODE_SIGN_STYLE'                       => 'Manual',
    'DEVELOPMENT_TEAM'                      => TEAM_ID,
    'MARKETING_VERSION'                     => '$(FLUTTER_BUILD_NAME)',
    'CURRENT_PROJECT_VERSION'               => '$(FLUTTER_BUILD_NUMBER)',
    'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'YES',
    'ENABLE_BITCODE'                        => 'NO',
    'LD_RUNPATH_SEARCH_PATHS'               => '$(inherited) @executable_path/Frameworks',
  })
  config.build_settings['CODE_SIGN_IDENTITY'] =
    config.name == 'Release' ? 'Apple Distribution' : 'Apple Development'
end

# ── Source file group ────────────────────────────────────────────────────────
watch_group = project.main_group.find_subpath(WATCH_SOURCE_DIR, true)
watch_group.set_source_tree('<group>')
watch_group.set_path(WATCH_SOURCE_DIR)

sources_phase = watch_target.source_build_phase

%w[MajuRunWatchApp.swift WatchSessionManager.swift ContentView.swift].each do |f|
  ref = watch_group.new_reference(f)
  ref.last_known_file_type = 'sourcecode.swift'
  sources_phase.add_file_reference(ref)
end

watch_group.new_reference('Info.plist')
watch_group.new_reference('MajuRunWatch.entitlements')

# ── WatchConnectivity framework (WatchKit already added by new_target) ────────
fw_group = project.frameworks_group
wc_ref   = fw_group.new_reference('WatchConnectivity.framework')
wc_ref.name        = 'WatchConnectivity.framework'
wc_ref.path        = 'System/Library/Frameworks/WatchConnectivity.framework'
wc_ref.source_tree = 'SDKROOT'
wc_ref.last_known_file_type = 'wrapper.framework'
watch_target.frameworks_build_phase.add_file_reference(wc_ref)

# ── Embed watch content in Runner ────────────────────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }
abort('❌ Runner target not found') unless runner_target

embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name               = 'Embed Watch Content'
embed_phase.dst_subfolder_spec = '16'   # Watch application folder
embed_phase.dst_path           = '$(CONTENTS_FOLDER_PATH)/Watch'
runner_target.build_phases << embed_phase

embed_file = embed_phase.add_file_reference(watch_target.product_reference)
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ── Save ─────────────────────────────────────────────────────────────────────
project.save

puts "✅ Watch target added successfully."
puts "   Bundle ID : #{WATCH_BUNDLE_ID}"
puts "   Source dir: ios/#{WATCH_SOURCE_DIR}"

#!/usr/bin/env ruby
# frozen_string_literal: true
#
# add_watch_target.rb — Adds the MajuRunWatch watchOS target to Runner.xcodeproj
# without needing Xcode open. Runs on the macOS CI runner before xcodebuild.
#
# Usage: ruby ios/scripts/add_watch_target.rb
# Idempotent: safe to run on every build (exits early if target already exists).

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH     = File.expand_path('../Runner.xcodeproj', __dir__)
WATCH_NAME       = 'MajuRunWatch'
WATCH_BUNDLE_ID  = 'com.majurun.app.watchkitapp'
WATCH_SOURCE_DIR = 'MajuRunWatch Watch App'   # relative to ios/
TEAM_ID          = ENV.fetch('TEAM_ID', 'RG52X42W22')

project = Xcodeproj::Project.open(PROJECT_PATH)

# ── Idempotency check ────────────────────────────────────────────────────────
if project.targets.any? { |t| t.name == WATCH_NAME }
  puts "✅ Watch target '#{WATCH_NAME}' already exists — nothing to do."
  exit 0
end

puts "➕ Adding watchOS target '#{WATCH_NAME}'..."

# ── Create watch app target ──────────────────────────────────────────────────
watch_target = project.new_target(
  :application,
  WATCH_NAME,
  :watchos,
  '8.0'
)

# ── Build settings ───────────────────────────────────────────────────────────
watch_target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']  = WATCH_BUNDLE_ID
  s['SDKROOT']                    = 'watchos'
  s['TARGETED_DEVICE_FAMILY']     = '4'
  s['WATCHOS_DEPLOYMENT_TARGET']  = '8.0'
  s['SWIFT_VERSION']              = '5.0'
  s['INFOPLIST_FILE']             = "#{WATCH_SOURCE_DIR}/Info.plist"
  s['CODE_SIGN_STYLE']            = 'Manual'
  s['DEVELOPMENT_TEAM']           = TEAM_ID
  s['MARKETING_VERSION']          = '$(FLUTTER_BUILD_NAME)'
  s['CURRENT_PROJECT_VERSION']    = '$(FLUTTER_BUILD_NUMBER)'
  s['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  s['ENABLE_BITCODE']             = 'NO'

  if config.name == 'Release'
    s['CODE_SIGN_IDENTITY']       = 'Apple Distribution'
  else
    s['CODE_SIGN_IDENTITY']       = 'Apple Development'
  end
end

# ── Source file group ────────────────────────────────────────────────────────
watch_group = project.main_group.find_subpath(WATCH_SOURCE_DIR, true)
watch_group.set_source_tree('<group>')
watch_group.set_path(WATCH_SOURCE_DIR)

%w[MajuRunWatchApp.swift WatchSessionManager.swift ContentView.swift].each do |f|
  ref = watch_group.new_reference(f)
  watch_target.source_build_phase.add_file_reference(ref)
end

watch_group.new_reference('Info.plist')

# ── WatchConnectivity framework ──────────────────────────────────────────────
fw_group = project['Frameworks'] || project.frameworks_group
wc_ref   = fw_group.new_reference('WatchConnectivity.framework')
wc_ref.name         = 'WatchConnectivity.framework'
wc_ref.path         = 'System/Library/Frameworks/WatchConnectivity.framework'
wc_ref.source_tree  = 'SDKROOT'
watch_target.frameworks_build_phase.add_file_reference(wc_ref)

# ── Embed watch content in Runner ────────────────────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }
abort('❌ Runner target not found') unless runner_target

embed_phase = runner_target.new_copy_files_build_phase('Embed Watch Content')
embed_phase.dst_subfolder_spec = '16'   # Watch application

# The watch product reference is created by new_target automatically
watch_product_ref = watch_target.product_reference
build_file = embed_phase.add_file_reference(watch_product_ref)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ── Save ─────────────────────────────────────────────────────────────────────
project.save
puts "✅ Watch target added and project saved."
puts "   Bundle ID : #{WATCH_BUNDLE_ID}"
puts "   Source dir: ios/#{WATCH_SOURCE_DIR}"

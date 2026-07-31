# Adds the TidalWidget WidgetKit extension to ios/Runner.xcodeproj.
#
# Done as a script rather than through the Xcode UI so it is reproducible and
# reviewable — `flutter create` regenerates the project on a clean checkout, and
# a hand-clicked target would be lost with no record of what was configured.
#
# Idempotent: re-running removes the existing target first.
#
# Usage: ruby tools/add_widget_target.rb
require 'xcodeproj'

PROJECT   = 'ios/Runner.xcodeproj'
NAME      = 'TidalWidget'
APP_ID    = 'com.mypeblo.tidal'
WIDGET_ID = "#{APP_ID}.#{NAME}"
DEPLOY    = '17.0'

project = Xcodeproj::Project.open(PROJECT)
runner  = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'

# --- clean slate ------------------------------------------------------------
project.targets.select { |t| t.name == NAME }.each do |t|
  runner.dependencies.select { |d| d.target == t }.each(&:remove_from_project)
  t.remove_from_project
end
project.main_group.children.select { |g| g.respond_to?(:name) && g.name == NAME }
       .each(&:remove_from_project)
runner.build_phases.select { |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.name == 'Embed Foundation Extensions'
}.each(&:remove_from_project)

# --- target -----------------------------------------------------------------
widget = project.new_target(:app_extension, NAME, :ios, DEPLOY)

group = project.main_group.new_group(NAME, NAME)
sources = Dir.glob("ios/#{NAME}/**/*.swift").sort
abort 'no widget sources found' if sources.empty?

sources.each do |path|
  ref = group.new_reference(File.expand_path(path))
  widget.add_file_references([ref])
end

assets = group.new_reference(File.expand_path("ios/#{NAME}/Assets.xcassets"))
widget.add_resources([assets])

# Referenced by build settings, not compiled — added to the group only so they
# are visible and editable in Xcode.
group.new_reference(File.expand_path("ios/#{NAME}/Info.plist"))
group.new_reference(File.expand_path("ios/#{NAME}/#{NAME}.entitlements"))

# iOS refuses to install an extension with no CFBundleVersion, and
# $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER) are injected only into Runner —
# for any other target they expand to nothing. So source the version from
# pubspec, which keeps one place to change it.
pubspec = File.read('pubspec.yaml')[/^version:\s*(\S+)/, 1] or abort 'no version in pubspec.yaml'
marketing, build_no = pubspec.split('+')

widget.build_configurations.each do |c|
  c.build_settings.merge!(
    'MARKETING_VERSION'            => marketing,
    'CURRENT_PROJECT_VERSION'      => build_no || '1',
    'PRODUCT_BUNDLE_IDENTIFIER'    => WIDGET_ID,
    'PRODUCT_NAME'                 => NAME,
    'INFOPLIST_FILE'               => "#{NAME}/Info.plist",
    'CODE_SIGN_ENTITLEMENTS'       => "#{NAME}/#{NAME}.entitlements",
    'IPHONEOS_DEPLOYMENT_TARGET'   => DEPLOY,
    'SWIFT_VERSION'                => '5.0',
    'TARGETED_DEVICE_FAMILY'       => '1,2',
    'SKIP_INSTALL'                 => 'YES',
    'GENERATE_INFOPLIST_FILE'      => 'NO',
    'CODE_SIGNING_ALLOWED'         => 'NO',
    'CODE_SIGNING_REQUIRED'        => 'NO',
    'CODE_SIGN_IDENTITY'           => '',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => '',
    # The extension links WidgetKit/SwiftUI/AppIntents via autolinking; it must
    # NOT inherit the app's Flutter/Firebase search paths.
    'SWIFT_OPTIMIZATION_LEVEL'     => c.name == 'Debug' ? '-Onone' : '-O'
  )
end

# --- embed into the app -----------------------------------------------------
runner.add_dependency(widget)

embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
build_file = embed.add_file_reference(widget.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# The embed MUST run before Flutter's "Thin Binary" script. That script both
# depends on Info.plist and is depended upon by the appex copy, so putting the
# embed after it produces "Cycle inside Runner" and the build refuses to run.
runner.build_phases.delete(embed)
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.insert(thin, embed)
else
  runner.build_phases << embed
end

# --- App Group on the app side too ------------------------------------------
# Both halves need the entitlement or they get separate containers and the
# widget silently reads an empty cache forever.
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
unless project.main_group['Runner'].files.any? { |f| f.path == 'Runner.entitlements' }
  project.main_group['Runner'].new_reference('Runner.entitlements')
end

project.save
puts "added #{NAME} (#{WIDGET_ID}) with #{sources.length} sources"
puts "runner phases: #{runner.build_phases.map { |p| p.display_name }.join(' | ')}"

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dynamic_notification_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'dynamic_notification_kit'
  s.version          = '0.0.1'
  s.summary          = 'Live delivery tracking and minimal notifications (Android Live Updates, iOS Live Activities).'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/intersmart/dynamic_notification_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Intersmart' => 'dev@intersmart.in' }
  s.source           = { :path => '.' }
  s.source_files = 'dynamic_notification_kit/Sources/dynamic_notification_kit/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.weak_frameworks = 'ActivityKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'dynamic_notification_kit_privacy' => ['dynamic_notification_kit/Sources/dynamic_notification_kit/PrivacyInfo.xcprivacy']}
end

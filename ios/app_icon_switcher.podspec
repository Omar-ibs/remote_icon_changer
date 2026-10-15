#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_icon_switcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_icon_switcher'
  s.version          = '0.1.0'
  s.summary          = 'Switch between app icons bundled in the app.'
  s.description      = <<-DESC
Switch the home-screen icon among alternate icons bundled in the app.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Omar Ibrahim' => 'ammaromar916@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'app_icon_switcher/Sources/app_icon_switcher/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'app_icon_switcher_privacy' => ['app_icon_switcher/Sources/app_icon_switcher/PrivacyInfo.xcprivacy']}
end

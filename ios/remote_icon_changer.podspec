#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint remote_icon_changer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'remote_icon_changer'
  s.version          = '0.1.0'
  s.summary          = 'Switch between app icons bundled in the app.'
  s.description      = <<-DESC
Switch the home-screen icon among alternate icons bundled in the app.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Omar Ibrahim' => 'ammaromar916@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'remote_icon_changer/Sources/remote_icon_changer/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'remote_icon_changer_privacy' => ['remote_icon_changer/Sources/remote_icon_changer/PrivacyInfo.xcprivacy']}
end

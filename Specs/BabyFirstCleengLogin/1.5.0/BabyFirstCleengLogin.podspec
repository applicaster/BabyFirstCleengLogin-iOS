Pod::Spec.new do |s|
  s.name                = 'BabyFirstCleengLogin'
  s.version             = '1.5.0'
  s.summary             = 'A plugin for Cleeng login & subscription for Zapp iOS.'
  s.description         = 'Plugin to make login & subscription with Cleeng for baby apps'
  s.homepage            = 'https://github.com/applicaster/BabyFirstCleengLogin-iOS/'
  s.license             = 'MIT'
  s.author              = { 'Roi Kedarya' => 'r.kedarya@applicaster.com' }
  s.source              = { :git => 'git@github.com:applicaster/BabyFirstCleengLogin-iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = "10.0"
  s.platform            = :ios, '10.0'
  s.requires_arc        = true
  s.swift_version       = '5.0'

  s.subspec 'Core' do |c|
    c.frameworks = 'UIKit'
    c.source_files = 'Classes/**/*.{swift}'
    c.resource_bundles = {
        'cleeng-storyboard' => ['Storyboard/*.{storyboard,png,xib}']
    }
    c.dependency 'ZappPlugins'
    c.dependency 'ApplicasterSDK'
    c.dependency 'FBSDKLoginKit'
    c.dependency 'FBSDKCoreKit'
    c.dependency 'FacebookLogin'
    c.dependency 'SwiftyStoreKit', '~> 0.15.0'
  end

  s.xcconfig =  { 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
                  'ENABLE_BITCODE' => 'YES',
                  'SWIFT_VERSION' => '5.0'
                }

  s.default_subspec = 'Core'

end

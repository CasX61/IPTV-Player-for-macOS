platform :macos, '14.0'

target 'IPTV' do
  use_frameworks!
  pod 'VLCKit', '~> 3.6'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end

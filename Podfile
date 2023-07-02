source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
platform :ios, '12.0'
#platform :osx, '11.0'
pod 'GRDB.swift'

target 'WikiFind' do
  pod 'ActionSheetPicker-3.0'
  pod 'FontAwesome.swift'
  #pod 'GoogleMaterialIconFont'
  #pod 'GoogleMaterialDesignIcons'


  target 'WikiFindTests' do
    inherit! :search_paths
    #pod 'OCMock', '~> 2.0.1'
  end
end

post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
               end
          end
   end
end

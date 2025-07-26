# Uncomment the next line to define a global platform for your project
platform :ios, '17.0'

target 'InstantRec' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Google Drive API and Authentication
  pod 'GoogleAPIClientForREST/Drive', '~> 3.0'
  pod 'GoogleSignIn', '~> 7.0'
  
  # Additional Google APIs if needed in the future
  # pod 'GoogleAPIClientForREST/Sheets', '~> 3.0'

end

# Post install script to fix common issues
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      
      # Fix for GoogleSignIn and other Google libraries
      if target.name == 'GoogleSignIn' || target.name.start_with?('GoogleAPIClientForREST')
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end
end
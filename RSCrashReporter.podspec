require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name             = 'RSCrashReporter'
  s.version          = package['version']
  s.summary          = "Privacy and Security focused Segment-alternative. iOS ,tvOS and watchOS SDK"
  s.description      = <<-DESC
  Rudder is a platform for collecting, storing and routing customer event data to dozens of tools. Rudder is open-source, can run in your cloud environment (AWS, GCP, Azure or even your data-centre) and provides a powerful transformation framework to process your event data on the fly.
                       DESC

  s.homepage         = "https://github.com/rudderlabs/rudder-crash-reporter-ios"
  s.license          = { :type => "Apache", :file => "LICENSE" }
  s.author           = { "RudderStack" => "sdk-accounts@rudderstack.com" }
  s.source           = { :git => "https://github.com/rudderlabs/crash-reporter-ios.git", :tag => "v#{s.version}" }

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '7.0'
  s.osx.deployment_target =  '10.11'
  s.libraries = 'c++', 'z'
  
  s.swift_versions = ['5.0']
  s.requires_arc = true
  s.prefix_header_file = false
  s.compiler_flags = [ "-fvisibility=hidden" ]
  
  s.source_files = 'RSCrashReporter/**/*.{m,h,mm,c}'
  s.public_header_files = 'RSCrashReporter/include/RSCrashReporter/*.h'
end

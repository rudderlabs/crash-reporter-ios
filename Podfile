source 'https://github.com/CocoaPods/Specs.git'
workspace 'RSCrashReporter.xcworkspace'
use_frameworks!
inhibit_all_warnings!

def shared_pods
    pod 'RSCrashReporter', :path => '.'
end

target 'SampleSwift' do
    project 'Examples/SampleSwift/SampleSwift.xcodeproj'
    platform :ios, '12.0'
    shared_pods
end

target 'SampleObjC' do
    project 'Examples/SampleObjC/SampleObjC.xcodeproj'
    platform :ios, '12.0'
    shared_pods
end

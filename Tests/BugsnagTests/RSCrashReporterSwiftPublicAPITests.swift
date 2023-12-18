//
//  RSCrashReporterSwiftPublicAPITests.swift
//  Tests
//
//  Created by Robin Macharg on 15/05/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

import XCTest

/**
 * Test all public APIs from Swift.  Purely existence tests, no attempt to verify correctness
 */

class FakePlugin: NSObject, RSCrashReporterPlugin {
    func load(_ client: RSCrashReporterClient) {}
    func unload() {}
}

// MetadataStore conformance - presence of required methods is a test in and of itself
class myMetadata: NSObject, RSCrashReporterMetadataStore, RSCrashReporterClassLevelMetadataStore {
    static func addMetadata(_ metadata: [AnyHashable : Any], section sectionName: String) {}
    static func addMetadata(_ metadata: Any?, key: String, section sectionName: String) {}
    static func getMetadata(section sectionName: String) -> NSMutableDictionary? { return NSMutableDictionary() }
    static func getMetadata(section sectionName: String, key: String) -> Any? { return nil }
    static func clearMetadata(section sectionName: String) {}
    static func clearMetadata(section sectionName: String, key: String) {}
    
    func addMetadata(_ metadata: [AnyHashable : Any], section sectionName: String) {}
    func addMetadata(_ metadata: Any?, key: String, section sectionName: String) {}
    func getMetadata(section sectionName: String) -> NSMutableDictionary? { return NSMutableDictionary() }
    func getMetadata(section sectionName: String, key: String) -> Any? { return nil }
    func clearMetadata(section sectionName: String) {}
    func clearMetadata(section sectionName: String, key: String) {}
}

class RSCrashReporterSwiftPublicAPITests: XCTestCase {

    let apiKey = "01234567890123456789012345678901"
    let ex = NSException(name: NSExceptionName("exception"),
                         reason: "myReason",
                         userInfo: nil)
    let err = NSError(domain: "dom", code: 123, userInfo: nil)
    let sessionBlock: RSCrashReporterOnSessionBlock = { (session) -> Bool in return false }
    let onSendErrorBlock: RSCrashReporterOnSendErrorBlock = { (event) -> Bool in return false }
    let onBreadcrumbBlock: RSCrashReporterOnBreadcrumbBlock = { (breadcrumb) -> Bool in return false }
    
    func testRSCrashReporterClass() throws {
        RSCrashReporter.start(with: nil)
        
        RSCrashReporter.notify(ex)
        RSCrashReporter.notify(ex) { (event) -> Bool in return false }
        RSCrashReporter.notifyError(err)
        RSCrashReporter.notifyError(err) { (event) -> Bool in return false }
        
        RSCrashReporter.leaveBreadcrumb(withMessage: "msg")
        RSCrashReporter.leaveBreadcrumb(forNotificationName: "notif")
        RSCrashReporter.leaveBreadcrumb("msg", metadata: ["foo" : "bar"], type: .error)
    }

    func testRSCrashReporterConfigurationClass() throws {
        let config = RSCrashReporterConfiguration(apiKey)

        config.apiKey = apiKey
        config.releaseStage = "stage1"
        config.enabledReleaseStages = nil
        config.enabledReleaseStages = ["one", "two", "three"]
        config.redactedKeys = nil
        config.redactedKeys = ["1", 2, 3]
        let re = try! NSRegularExpression(pattern: "test", options: [])
        config.redactedKeys = ["a", "a", "b", re]
        config.context = nil
        config.context = "ctx"
        config.appVersion = nil
        config.appVersion = "vers"
        config.session = URLSession(configuration: URLSessionConfiguration.default);
#if !os(watchOS)
        config.sendThreads = .always
#endif

        config.onCrashHandler = nil
        config.onCrashHandler = { (writer) in }
        let crashHandler: (@convention(c)(UnsafePointer<RSC_KSCrashReportWriter>) -> Void)? = { writer in }
        config.onCrashHandler = crashHandler
        
        config.autoDetectErrors = true
        config.autoTrackSessions = true
        config.enabledBreadcrumbTypes = .all
        config.bundleVersion = nil
        config.bundleVersion = "bundle"
        config.appType = nil
        config.appType = "appType"
        config.maxBreadcrumbs = 999
        config.persistUser = true
        
        let errorTypes =  RSCrashReporterErrorTypes()
        errorTypes.cppExceptions = true
#if !os(watchOS)
        errorTypes.ooms = true
        errorTypes.machExceptions = true
        errorTypes.signals = true
#endif
        errorTypes.unhandledExceptions = true
        errorTypes.unhandledRejections = true
        config.enabledErrorTypes = errorTypes
        
        config.endpoints = RSCrashReporterEndpointConfiguration()
        config.endpoints = RSCrashReporterEndpointConfiguration(notify: "http://test.com", sessions: "http://test.com")
        
        config.setUser("user", withEmail: "email", andName: "name")
        let onSession = config.addOnSession(block: sessionBlock)
        config.addOnSession { (session: RSCrashReporterSession) -> Bool in
            return true
        }
        config.removeOnSession(onSession)
        config.addOnSendError(block:onSendErrorBlock)
        config.addOnSendError { (event: RSCrashReporterEvent) -> Bool in
            return true
        }
        config.removeOnSendError(onSession)
        let onBreadcrumb = config.addOnBreadcrumb(block: onBreadcrumbBlock)
        config.addOnBreadcrumb { (breadcrumb: RSCrashReporterBreadcrumb) -> Bool in
            return true
        }
        config.removeOnBreadcrumb(onBreadcrumb)
        
        let plugin = FakePlugin()
        config.add(plugin)
    }
    
    // Also test <RSCrashReporterMetadataStore> behaviour
    func testRSCrashReporterMetadataClass() throws {
        var md = RSCrashReporterMetadata()
        md = RSCrashReporterMetadata(dictionary: ["foo" : "bar"])
        
        md.addMetadata(["key" : "secret"], section: "mental")
        md.addMetadata("spock", key: "kirk", section: "enterprise")
        md.getMetadata(section: "mental")
        md.getMetadata(section: "mental", key: "key")
        md.clearMetadata(section: "enterprise")
        md.clearMetadata(section: "enterprise", key: "key")
    }
    
    func testRSCrashReporterEventClass() throws {
        let event = RSCrashReporterEvent()
        
        event.context = nil
        event.context = "ctx"
        event.errors = []
        event.errors = [RSCrashReporterError()]
        event.groupingHash = nil
        event.groupingHash = "1234"
        event.breadcrumbs = []
        event.breadcrumbs = [RSCrashReporterBreadcrumb()]
        event.apiKey = apiKey
        _ = event.device
        _ = event.app
        _ = event.unhandled
        event.threads = []
        event.threads = [RSCrashReporterThread()]
        event.originalError = nil
        event.originalError = 123
        event.originalError = RSCrashReporterError()
//        _ = event.user
        event.setUser("user", withEmail: "email", andName: "name")
        event.severity = .error
        _ = event.severity
    }
    
    func testRSCrashReporterAppWithStateClass() throws {
        let app = RSCrashReporterAppWithState()
        
        app.bundleVersion = nil
        app.bundleVersion = "bundle"
        _ = app.bundleVersion
        
        app.codeBundleId = nil
        app.codeBundleId = "bundle"
        _ = app.codeBundleId
        
        app.dsymUuid = nil
        app.dsymUuid = "bundle"
        _ = app.dsymUuid
        
        app.id = nil
        app.id = "bundle"
        _ = app.id
        
        app.releaseStage = nil
        app.releaseStage = "bundle"
        _ = app.releaseStage
        
        app.type = nil
        app.type = "bundle"
        _ = app.type
        
        app.version = nil
        app.version = "bundle"
        _ = app.version
        
        // withState
        
        app.duration = nil
        app.duration = 0
        app.duration = 1.1
        app.duration = -45
        app.duration = NSNumber(booleanLiteral: true)
        _ = app.duration
        
        app.durationInForeground = nil
        app.durationInForeground = 0
        app.durationInForeground = 1.1
        app.durationInForeground = -45
        app.durationInForeground = NSNumber(booleanLiteral: true)
        _ = app.durationInForeground
        
        app.inForeground = true
        _ = app.inForeground
        
    }

    func testRSCrashReporterBreadcrumbClass() throws {
        let breadcrumb = RSCrashReporterBreadcrumb()
        breadcrumb.type = .manual
        breadcrumb.message = "message"
        breadcrumb.metadata = [:]
    }

    func testRSCrashReporterClientClass() throws {
        var client = RSCrashReporterClient()
        let config = RSCrashReporterConfiguration(apiKey)
        client = RSCrashReporterClient(configuration: config, delegate: nil)
        client.notify(ex)
        client.notify(ex) { (event) -> Bool in return false }
        client.notifyError(err)
        client.notifyError(err) { (event) -> Bool in return false }
     
        client.leaveBreadcrumb(withMessage: "msg")
        client.leaveBreadcrumb("msg", metadata: [:], type: .manual)
        client.leaveBreadcrumb(forNotificationName: "name")
        
        client.startSession()
        client.pauseSession()
        client.resumeSession()
        
        client.context = nil
        client.context = ""
        _ = client.context
        
        let _ = client.lastRunInfo?.crashed
        
        client.setUser("me", withEmail: "memail@foo.com", andName: "you")
        let _ = client.user()
        
        let onSession = client.addOnSession(block: sessionBlock)
        client.addOnSession { (session: RSCrashReporterSession) -> Bool in
            return true
        }
        client.removeOnSession(onSession)
        
        let onBreadcrumb = client.addOnBreadcrumb(block: onBreadcrumbBlock)
        client.addOnBreadcrumb { (breadcrumb: RSCrashReporterBreadcrumb) -> Bool in
            return true
        }
        client.removeOnBreadcrumb(onBreadcrumb)
    }

    func testRSCrashReporterDeviceWithStateClass() throws {
        let device = RSCrashReporterDeviceWithState()
        
        device.jailbroken = false
        _ = device.jailbroken
        
        device.id = nil
        device.id = "id"
        _ = device.id
        
        device.locale = nil
        device.locale = "locale"
        _ = device.locale
        
        device.manufacturer = nil
        device.manufacturer = "man"
        _ = device.manufacturer
        device.model = nil
        device.model = "model"
        _ = device.model
        device.modelNumber = nil
        device.modelNumber = "model"
        _ = device.modelNumber
        device.osName = nil
        device.osName = "name"
        _ = device.osName
        device.osVersion = nil
        device.osVersion = "version"
        _ = device.osVersion
        device.runtimeVersions = nil
        device.runtimeVersions = [:]
        device.runtimeVersions = ["a" : "b"]
        _ = device.runtimeVersions
        device.totalMemory = nil
        device.totalMemory = 1234
        _ = device.totalMemory
        
        // withState
        
        device.freeDisk = nil
        device.freeDisk = 0
        device.freeDisk = 1.1
        device.freeDisk = -45
        device.freeDisk = NSNumber(booleanLiteral: true)
        _ = device.freeDisk
        
        device.freeMemory = nil
        device.freeMemory = 0
        device.freeMemory = 1.1
        device.freeMemory = -45
        device.freeMemory = NSNumber(booleanLiteral: true)
        _ = device.freeMemory
        
        device.orientation = nil
        device.orientation = "upside your head"
        _ = device.orientation
        
        device.time = nil
        device.time = Date()
        _ = device.time
    }

    func testRSCrashReporterEndpointConfigurationlass() throws {
        let epc = RSCrashReporterEndpointConfiguration()
        epc.notify = "notify"
        epc.sessions = "sessions"
    }

    // Also error types
    func testRSCrashReporterErrorClass() throws {
        let e = RSCrashReporterError()
        e.errorClass = nil
        e.errorClass = "class"
        _ = e.errorClass
        e.errorMessage = nil
        e.errorMessage = "msg"
        _ = e.errorMessage
        
        e.type = .cocoa
        e.type = .c
        e.type = .reactNativeJs
        e.type = .cSharp
    }

    func testRSCrashReporterSessionClass() throws {
        let session = RSCrashReporterSession()
        session.id = "id"
        _ = session.id
        session.startedAt = Date()
        _ = session.startedAt
        _ = session.app
        _ = session.device
        _ = session.user
        session.setUser("user", withEmail: "email", andName: "name")
    }

    func testRSCrashReporterStackframeClass() throws {
        let sf = RSCrashReporterStackframe()
        sf.method = nil
        sf.method = "method"
        _ = sf.method
        sf.machoFile = nil
        sf.machoFile = "file"
        _ = sf.machoFile
        sf.machoUuid = nil
        sf.machoUuid = "uuid"
        _ = sf.machoUuid
        sf.frameAddress = nil
        sf.frameAddress = 123
        _ = sf.frameAddress
        sf.machoVmAddress = nil
        sf.machoVmAddress = 123
        _ = sf.machoVmAddress
        sf.symbolAddress = nil
        sf.symbolAddress = 123
        _ = sf.symbolAddress
        sf.machoLoadAddress = nil
        sf.machoLoadAddress = 123
        _ = sf.machoLoadAddress
        sf.isPc = true
        _ = sf.isPc
        sf.isLr = true
        _ = sf.isLr
    }

    func testRSCrashReporterThreadClass() throws {
        let thread = RSCrashReporterThread()
        thread.id = nil
        thread.id = "id"
        _ = thread.id
        thread.name = nil
        thread.name = "name"
        _ = thread.name
        thread.type = .cocoa
        _ = thread.errorReportingThread
        _ = thread.stacktrace
    }

    func testRSCrashReporterUserClass() throws {
        let user = RSCrashReporterUser()
        _ = user.id
        _ = user.email
        _ = user.name
    }
}

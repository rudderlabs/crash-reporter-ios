//
//  RSCNotificationBreadcrumbsTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 10/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <RSCrashReporter/RSCrashReporter.h>

#import "RSCNotificationBreadcrumbs.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCDefines.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import "UISceneStub.h"
#endif


@interface RSCNotificationBreadcrumbsTests : XCTestCase <RSCBreadcrumbSink>

@property NSNotificationCenter *notificationCenter;
@property id notificationObject;
@property NSDictionary *notificationUserInfo;

@property RSCNotificationBreadcrumbs *notificationBreadcrumbs;
@property (nonatomic) RSCrashReporterBreadcrumb *breadcrumb;

@end


#pragma mark Mock Objects

@interface RSCMockObject: NSObject
@property(readwrite, strong) NSString *descriptionString;
@end

@implementation RSCMockObject
- (NSString *)description {return self.descriptionString;}
@end


@interface RSCMockScene: RSCMockObject
@property(readwrite, strong) NSString *title;
@property(readwrite, strong) NSString *subtitle;
@end

@implementation RSCMockScene
@end


@interface RSCMockViewController: RSCMockObject
@property(readwrite, strong) NSString *title;
@end

@implementation RSCMockViewController
@end

#if RSC_HAVE_WINDOW

#if TARGET_OS_OSX
@interface RSCMockWindow: NSWindow
#else
@interface RSCMockWindow: UIWindow
#endif
@property(readwrite, strong) NSString *mockDescription;
@property(readwrite, strong) NSString *mockTitle;
@property(readwrite, strong) NSString *mockRepresentedURLString;
@property(readwrite, strong) RSCMockScene *mockScene;
@property(readwrite, strong) RSCMockViewController *mockViewController;
@end

@implementation RSCMockWindow
- (NSString *)description {return self.mockDescription;}
#if TARGET_OS_OSX
- (NSViewController *)contentViewController {return (NSViewController *)self.mockViewController;}
- (NSString *)title {return self.mockTitle;}
- (NSURL *)representedURL {return [NSURL URLWithString:self.mockRepresentedURLString];}
#else
#if !TARGET_OS_TV && (defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0)
- (UIScene *)windowScene  {return (UIScene *)self.mockScene;}
#endif
- (UIViewController *)rootViewController {return (UIViewController *)self.mockViewController;}
#endif
@end

#endif


#if TARGET_OS_IOS
@interface MockDevice : NSObject
@property UIDeviceOrientation orientation;
@end

@implementation MockDevice
@end
#endif


@interface MockProcessInfo : NSObject
@property NSProcessInfoThermalState thermalState API_AVAILABLE(ios(11.0), tvos(11.0));
@end

@implementation MockProcessInfo
@end


#pragma mark -

@implementation RSCNotificationBreadcrumbsTests

#pragma mark Setup

- (void)setUp {
    self.breadcrumb = nil;
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    self.notificationBreadcrumbs = [[RSCNotificationBreadcrumbs alloc] initWithConfiguration:configuration breadcrumbSink:self];
    self.notificationBreadcrumbs.notificationCenter = [[NSNotificationCenter alloc] init];
    self.notificationBreadcrumbs.workspaceNotificationCenter = [[NSNotificationCenter alloc] init];
    self.notificationCenter = self.notificationBreadcrumbs.notificationCenter; 
    self.notificationObject = nil;
    self.notificationUserInfo = nil;
    [self.notificationBreadcrumbs start];
}

- (RSCrashReporterBreadcrumb *)breadcrumbForNotificationWithName:(NSString *)name {
    self.breadcrumb = nil;
    [self.notificationCenter postNotification:
     [NSNotification notificationWithName:name object:self.notificationObject userInfo:self.notificationUserInfo]];
    return self.breadcrumb;
}

#pragma mark RSCBreadcrumbSink

- (void)leaveBreadcrumbWithMessage:(NSString *)message metadata:(NSDictionary *)metadata andType:(RSCBreadcrumbType)type {
    self.breadcrumb = [RSCrashReporterBreadcrumb new];
    self.breadcrumb.message = message;
    self.breadcrumb.metadata = metadata;
    self.breadcrumb.type = type;
}

#define TEST(__NAME__, __TYPE__, __MESSAGE__, __METADATA__) do { \
    RSCrashReporterBreadcrumb *breadcrumb = [self breadcrumbForNotificationWithName:__NAME__]; \
    XCTAssert([NSJSONSerialization isValidJSONObject:breadcrumb.metadata]); \
    if (breadcrumb) { \
        XCTAssertEqual(breadcrumb.type, __TYPE__); \
        XCTAssertEqualObjects(breadcrumb.message, __MESSAGE__); \
        XCTAssertEqualObjects(breadcrumb.metadata, __METADATA__); \
    } \
} while (0)

#pragma mark Tests

- (void)testNSUndoManagerNotifications {
    TEST(NSUndoManagerDidRedoChangeNotification, RSCBreadcrumbTypeState, @"Redo Operation", @{});
    TEST(NSUndoManagerDidUndoChangeNotification, RSCBreadcrumbTypeState, @"Undo Operation", @{});
}

- (void)testNSProcessInfoThermalStateThermalStateNotifications {
    if (@available(iOS 13.0, tvOS 13.0, watchOS 4.0, *)) {
        MockProcessInfo *processInfo = [[MockProcessInfo alloc] init];
        self.notificationObject = processInfo;
        
        // Set initial state
        processInfo.thermalState = NSProcessInfoThermalStateNominal;
        [self breadcrumbForNotificationWithName:NSProcessInfoThermalStateDidChangeNotification];
        
        processInfo.thermalState = NSProcessInfoThermalStateCritical;
        TEST(NSProcessInfoThermalStateDidChangeNotification, RSCBreadcrumbTypeState,
             @"Thermal State Changed", (@{@"from": @"nominal", @"to": @"critical"}));
        
        processInfo.thermalState = NSProcessInfoThermalStateCritical;
        XCTAssertNil([self breadcrumbForNotificationWithName:NSProcessInfoThermalStateDidChangeNotification],
                     @"No breadcrumb should be left if state did not change");
    }
}

#pragma mark iOS Tests

#if TARGET_OS_IOS

- (void)testUIApplicationNotifications {
    TEST(UIApplicationDidEnterBackgroundNotification, RSCBreadcrumbTypeState, @"App Did Enter Background", @{});
    TEST(UIApplicationDidReceiveMemoryWarningNotification, RSCBreadcrumbTypeState, @"Memory Warning", @{});
    TEST(UIApplicationUserDidTakeScreenshotNotification, RSCBreadcrumbTypeState, @"Took Screenshot", @{});
    TEST(UIApplicationWillEnterForegroundNotification, RSCBreadcrumbTypeState, @"App Will Enter Foreground", @{});
    TEST(UIApplicationWillTerminateNotification, RSCBreadcrumbTypeState, @"App Will Terminate", @{});
}
 
- (void)testUIDeviceOrientationNotifications {
    MockDevice *device = [[MockDevice alloc] init];
    self.notificationObject = device;
    
    // Set initial state
    device.orientation = UIDeviceOrientationPortrait;
    [self breadcrumbForNotificationWithName:UIDeviceOrientationDidChangeNotification];
    
    device.orientation = UIDeviceOrientationLandscapeLeft;
    TEST(UIDeviceOrientationDidChangeNotification, RSCBreadcrumbTypeState,
         @"Orientation Changed", (@{@"from": @"portrait", @"to": @"landscapeleft"}));
    
    device.orientation = UIDeviceOrientationUnknown;
    XCTAssertNil([self breadcrumbForNotificationWithName:UIDeviceOrientationDidChangeNotification],
                 @"UIDeviceOrientationUnknown should be ignored");
    
    device.orientation = UIDeviceOrientationLandscapeLeft;
    XCTAssertNil([self breadcrumbForNotificationWithName:UIDeviceOrientationDidChangeNotification],
                 @"No breadcrumb should be left if orientation did not change");
}

- (void)testUIKeyboardNotifications {
    TEST(UIKeyboardDidHideNotification, RSCBreadcrumbTypeState, @"Keyboard Became Hidden", @{});
    TEST(UIKeyboardDidShowNotification, RSCBreadcrumbTypeState, @"Keyboard Became Visible", @{});
}

- (void)testUIMenuNotifications {
    TEST(UIMenuControllerDidHideMenuNotification, RSCBreadcrumbTypeState, @"Did Hide Menu", @{});
    TEST(UIMenuControllerDidShowMenuNotification, RSCBreadcrumbTypeState, @"Did Show Menu", @{});
}

- (void)testUITextFieldNotifications {
    TEST(UITextFieldTextDidBeginEditingNotification, RSCBreadcrumbTypeUser, @"Began Editing Text", @{});
    TEST(UITextFieldTextDidEndEditingNotification, RSCBreadcrumbTypeUser, @"Stopped Editing Text", @{});
}

- (void)testUITextViewNotifications {
    TEST(UITextViewTextDidBeginEditingNotification, RSCBreadcrumbTypeUser, @"Began Editing Text", @{});
    TEST(UITextViewTextDidEndEditingNotification, RSCBreadcrumbTypeUser, @"Stopped Editing Text", @{});
}

- (void)testUIWindowNotificationsNoData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];

    TEST(UIWindowDidBecomeHiddenNotification, RSCBreadcrumbTypeState, @"Window Became Hidden", metadata);
    TEST(UIWindowDidBecomeVisibleNotification, RSCBreadcrumbTypeState, @"Window Became Visible", metadata);
}

- (void)testUIWindowNotificationsWithData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    window.mockDescription = @"Window Description";
    window.mockTitle = @"Window Title";
    window.mockRepresentedURLString = @"https://bugsnag.com";
    window.mockScene.title = @"Scene Title";
    window.mockScene.subtitle = @"Scene Subtitle";
    window.mockViewController.title = @"ViewController Title";
    window.mockViewController.descriptionString = @"ViewController Description";

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
    metadata[@"description"] = @"Window Description";
    metadata[@"viewController"] = @"ViewController Description";
    metadata[@"viewControllerTitle"] = @"ViewController Title";
    if (@available(iOS 13.0, *)) {
        metadata[@"sceneTitle"] = @"Scene Title";
    }
    if (@available(iOS 15.0, *)) {
        metadata[@"sceneSubtitle"] = @"Scene Subtitle";
    }

    TEST(UIWindowDidBecomeHiddenNotification, RSCBreadcrumbTypeState, @"Window Became Hidden", metadata);
    TEST(UIWindowDidBecomeVisibleNotification, RSCBreadcrumbTypeState, @"Window Became Visible", metadata);
}

#endif

#pragma mark iOS & tvOS Tests

#if TARGET_OS_IOS || TARGET_OS_TV

#if (defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0) || \
    (defined(__TVOS_13_0) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_13_0)

- (void)testUISceneNotifications {
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.notificationObject = [[UISceneStub alloc] initWithConfiguration:@"Default Configuration"
                                                               delegateClass:[RSCNotificationBreadcrumbsTests class]
                                                                        role:UIWindowSceneSessionRoleApplication
                                                                  sceneClass:[UISceneStub class]
                                                                       title:@"Home"];
        
        TEST(UISceneWillConnectNotification, RSCBreadcrumbTypeState, @"Scene Will Connect",
             (@{@"configuration": @"Default Configuration",
                @"delegateClass": @"RSCNotificationBreadcrumbsTests",
                @"role": @"UIWindowSceneSessionRoleApplication",
                @"sceneClass": @"UISceneStub",
                @"title": @"Home"}));
        
        self.notificationObject = nil;
        TEST(UISceneDidDisconnectNotification, RSCBreadcrumbTypeState, @"Scene Disconnected", @{});
        TEST(UISceneDidActivateNotification, RSCBreadcrumbTypeState, @"Scene Activated", @{});
        TEST(UISceneWillDeactivateNotification, RSCBreadcrumbTypeState, @"Scene Will Deactivate", @{});
        TEST(UISceneWillEnterForegroundNotification, RSCBreadcrumbTypeState, @"Scene Will Enter Foreground", @{});
        TEST(UISceneDidEnterBackgroundNotification, RSCBreadcrumbTypeState, @"Scene Entered Background", @{});
    }
}

#endif

- (void)testUITableViewNotifications {
    TEST(UITableViewSelectionDidChangeNotification, RSCBreadcrumbTypeNavigation, @"TableView Select Change", @{});
}

#endif

#pragma mark tvOS Tests

#if TARGET_OS_TV

- (void)testUIScreenNotifications {
    TEST(UIScreenBrightnessDidChangeNotification, RSCBreadcrumbTypeState, @"Screen Brightness Changed", @{});
}

- (void)testUIWindowNotificationsNoData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];

    TEST(UIWindowDidBecomeHiddenNotification, RSCBreadcrumbTypeState, @"Window Became Hidden", metadata);
    TEST(UIWindowDidBecomeKeyNotification, RSCBreadcrumbTypeState, @"Window Became Key", metadata);
    TEST(UIWindowDidBecomeVisibleNotification, RSCBreadcrumbTypeState, @"Window Became Visible", metadata);
    TEST(UIWindowDidResignKeyNotification, RSCBreadcrumbTypeState, @"Window Resigned Key", metadata);
}

- (void)testUIWindowNotificationsWithData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    window.mockDescription = @"Window Description";
    window.mockTitle = @"Window Title";
    window.mockRepresentedURLString = @"https://bugsnag.com";
    window.mockScene.title = @"Scene Title";
    window.mockScene.subtitle = @"Scene Subtitle";
    window.mockViewController.title = @"ViewController Title";
    window.mockViewController.descriptionString = @"ViewController Description";

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
    metadata[@"description"] = @"Window Description";
    metadata[@"viewController"] = @"ViewController Description";
    metadata[@"viewControllerTitle"] = @"ViewController Title";

    TEST(UIWindowDidBecomeHiddenNotification, RSCBreadcrumbTypeState, @"Window Became Hidden", metadata);
    TEST(UIWindowDidBecomeKeyNotification, RSCBreadcrumbTypeState, @"Window Became Key", metadata);
    TEST(UIWindowDidBecomeVisibleNotification, RSCBreadcrumbTypeState, @"Window Became Visible", metadata);
    TEST(UIWindowDidResignKeyNotification, RSCBreadcrumbTypeState, @"Window Resigned Key", metadata);
}

#endif

#pragma mark macOS Tests

#if TARGET_OS_OSX

- (void)testNSApplicationNotifications {
    TEST(NSApplicationDidBecomeActiveNotification, RSCBreadcrumbTypeState, @"App Became Active", @{});
    TEST(NSApplicationDidBecomeActiveNotification, RSCBreadcrumbTypeState, @"App Became Active", @{});
    TEST(NSApplicationDidHideNotification, RSCBreadcrumbTypeState, @"App Did Hide", @{});
    TEST(NSApplicationDidResignActiveNotification, RSCBreadcrumbTypeState, @"App Resigned Active", @{});
    TEST(NSApplicationDidUnhideNotification, RSCBreadcrumbTypeState, @"App Did Unhide", @{});
    TEST(NSApplicationWillTerminateNotification, RSCBreadcrumbTypeState, @"App Will Terminate", @{});
}

- (void)testNSControlNotifications {
    self.notificationObject = ({
        NSControl *control = [[NSControl alloc] init];
        control.accessibilityLabel = @"button1";
        control;
    });
    TEST(NSControlTextDidBeginEditingNotification, RSCBreadcrumbTypeUser, @"Control Text Began Edit", @{@"label": @"button1"});
    TEST(NSControlTextDidEndEditingNotification, RSCBreadcrumbTypeUser, @"Control Text Ended Edit", @{@"label": @"button1"});
}

- (void)testNSMenuNotifications {
    self.notificationUserInfo = @{@"MenuItem": [[NSMenuItem alloc] initWithTitle:@"menuAction:" action:nil keyEquivalent:@""]};
    TEST(NSMenuWillSendActionNotification, RSCBreadcrumbTypeState, @"Menu Will Send Action", @{@"action": @"menuAction:"});
}

- (void)testNSTableViewNotifications {
    self.notificationObject = [[NSTableView alloc] init];
    TEST(NSTableViewSelectionDidChangeNotification, RSCBreadcrumbTypeNavigation, @"TableView Select Change",
         (@{@"selectedColumn": @(-1), @"selectedRow": @(-1)}));
}

- (void)testNSWindowNotificationsNoData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];

    TEST(NSWindowDidBecomeKeyNotification, RSCBreadcrumbTypeState, @"Window Became Key", metadata);
    TEST(NSWindowDidEnterFullScreenNotification, RSCBreadcrumbTypeState, @"Window Entered Full Screen", metadata);
    TEST(NSWindowDidExitFullScreenNotification, RSCBreadcrumbTypeState, @"Window Exited Full Screen", metadata);
    TEST(NSWindowWillCloseNotification, RSCBreadcrumbTypeState, @"Window Will Close", metadata);
    TEST(NSWindowWillMiniaturizeNotification, RSCBreadcrumbTypeState, @"Window Will Miniaturize", metadata);
}

- (void)testNSWindowNotificationsWithData {
    RSCMockWindow *window = [[RSCMockWindow alloc]  init];
    window.mockScene = [[RSCMockScene alloc]  init];
    window.mockViewController = [[RSCMockViewController alloc] init];
    self.notificationObject = window;

    window.mockDescription = @"Window Description";
    window.mockTitle = @"Window Title";
    window.mockRepresentedURLString = @"https://bugsnag.com";
    window.mockScene.title = @"Scene Title";
    window.mockScene.subtitle = @"Scene Subtitle";
    window.mockViewController.title = @"ViewController Title";
    window.mockViewController.descriptionString = @"ViewController Description";

    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
    metadata[@"description"] = @"Window Description";
    metadata[@"title"] = @"Window Title";
    metadata[@"viewController"] = @"ViewController Description";
    metadata[@"viewControllerTitle"] = @"ViewController Title";
    metadata[@"representedURL"] = @"https://bugsnag.com";
#if defined(__MAC_11_0) && __MAC_OS_VERSION_MAX_ALLOWED >= __MAC_11_0
    if (@available(macOS 11.0, *)) {
        metadata[@"subtitle"] = @"Window Subtitle";
    }
#endif

    TEST(NSWindowDidBecomeKeyNotification, RSCBreadcrumbTypeState, @"Window Became Key", metadata);
    TEST(NSWindowDidEnterFullScreenNotification, RSCBreadcrumbTypeState, @"Window Entered Full Screen", metadata);
    TEST(NSWindowDidExitFullScreenNotification, RSCBreadcrumbTypeState, @"Window Exited Full Screen", metadata);
    TEST(NSWindowWillCloseNotification, RSCBreadcrumbTypeState, @"Window Will Close", metadata);
    TEST(NSWindowWillMiniaturizeNotification, RSCBreadcrumbTypeState, @"Window Will Miniaturize", metadata);
}

- (void)testNSWorkspaceNotifications {
    self.notificationCenter = self.notificationBreadcrumbs.workspaceNotificationCenter;
    TEST(NSWorkspaceScreensDidSleepNotification, RSCBreadcrumbTypeState, @"Workspace Screen Slept", @{});
    TEST(NSWorkspaceScreensDidWakeNotification, RSCBreadcrumbTypeState, @"Workspace Screen Awoke", @{});
}

#endif

@end

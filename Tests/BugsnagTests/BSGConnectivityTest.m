#import <XCTest/XCTest.h>

#import "RSCConnectivity.h"
#import "RSCDefines.h"

@interface RSCConnectivityTest : XCTestCase
@end

@implementation RSCConnectivityTest

- (void)tearDown {
    // Reset connectivity state cache
    RSCConnectivityShouldReportChange(0);
    [RSCConnectivity stopMonitoring];
}

- (void)testConnectivityRepresentations {
    XCTAssertEqualObjects(@"none", RSCConnectivityFlagRepresentation(0));
    XCTAssertEqualObjects(@"none", RSCConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsDirect));
    #if RSC_HAVE_REACHABILITY_WWAN
        // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
        XCTAssertEqualObjects(@"none", RSCConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN));
        XCTAssertEqualObjects(@"cellular", RSCConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable));
    #endif
    XCTAssertEqualObjects(@"wifi", RSCConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable));
    XCTAssertEqualObjects(@"wifi", RSCConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));
}

- (void)testValidHost {
    XCTAssertTrue([RSCConnectivity isValidHostname:@"example.com"]);
    // Could be an internal network hostname
    XCTAssertTrue([RSCConnectivity isValidHostname:@"foo"]);

    // Definitely will not work as expected
    XCTAssertFalse([RSCConnectivity isValidHostname:@""]);
    XCTAssertFalse([RSCConnectivity isValidHostname:nil]);
    XCTAssertFalse([RSCConnectivity isValidHostname:@"localhost"]);
    XCTAssertFalse([RSCConnectivity isValidHostname:@"127.0.0.1"]);
    XCTAssertFalse([RSCConnectivity isValidHostname:@"::1"]);
}

- (void)mockMonitorURLWithCallback:(RSCConnectivityChangeBlock)block {
    [RSCConnectivity monitorURL:[NSURL URLWithString:@""]
                  usingCallback:block];
}

@end

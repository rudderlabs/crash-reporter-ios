//
//  ViewController.m
//  SampleObjC
//
//  Created by Pallab Maiti on 19/06/23.
//

#import "ViewController.h"

@import RSCrashReporter;

@interface ViewController () <RSCrashReporterNotifyDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [RSCrashReporter startWithDelegate:self];
}

- (IBAction)onButtonTap:(id)sender {
//    [NSException raise:@"Test Exception" format:@""];
    @throw NSInternalInconsistencyException;
}

- (void)notifyCrashEvent:(BugsnagEvent * _Nullable)event withRequestPayload:(NSMutableDictionary * _Nullable)requestPayload {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestPayload
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"%@", jsonString);
        [[NSFileManager defaultManager] createFileAtPath:@"file.json" contents:nil attributes:nil];
        [jsonString writeToFile:@"file.json" atomically:YES encoding:NSUTF8StringEncoding error:nil];

    }
}

@end

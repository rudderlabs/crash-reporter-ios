#ifndef RSCrashReporterPlugin_h
#define RSCrashReporterPlugin_h

#import <Foundation/Foundation.h>

@class RSCrashReporter;
@class RSCrashReporterClient;

/**
 * Internal interface for adding custom behavior :nodoc:
 */
@protocol RSCrashReporterPlugin <NSObject>

@required

/**
 * Loads a plugin with the given Client. When this method is invoked the plugin should
 * activate its behaviour - for example, by capturing an additional source of errors.
*/
- (void)load:(RSCrashReporterClient *_Nonnull)client;

/**
 * Unloads a plugin. When this is invoked the plugin should cease all custom behaviour and
 * restore the application to its unloaded state.
 */
- (void)unload;

@end

#endif /* RSCrashReporterPlugin_h */

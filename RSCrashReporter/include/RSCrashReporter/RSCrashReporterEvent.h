//
//  RSCrashReporterEvent.h
//  RSCrashReporter
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>
#import <RSCrashReporter/RSCrashReporterFeatureFlagStore.h>
#import <RSCrashReporter/RSCrashReporterMetadataStore.h>

@class RSCrashReporterConfiguration;
@class RSCrashReporterHandledState;
@class RSCrashReporterSession;
@class RSCrashReporterBreadcrumb;
@class RSCrashReporterAppWithState;
@class RSCrashReporterDeviceWithState;
@class RSCrashReporterMetadata;
@class RSCrashReporterThread;
@class RSCrashReporterError;
@class RSCrashReporterUser;

/**
 * Represents the importance of a particular event.
 */
typedef NS_ENUM(NSUInteger, RSCSeverity) {
    RSCSeverityError,
    RSCSeverityWarning,
    RSCSeverityInfo,
};

/**
 * Represents an occurrence of an error, along with information about the state of the app and device.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterEvent : NSObject <RSCrashReporterFeatureFlagStore, RSCrashReporterMetadataStore>

// -----------------------------------------------------------------------------
// MARK: - Properties
// -----------------------------------------------------------------------------

/**
 *  A loose representation of what was happening in the application at the time
 *  of the event
 */
@property (readwrite, copy, nullable, nonatomic) NSString *context;

/**
 *  The severity of the error generating the report
 */
@property (readwrite, nonatomic) RSCSeverity severity;

/**
 * Information extracted from the error that caused the event. The list contains
 * at least one error that represents the root cause, with subsequent elements populated
 * from the cause.
 */
@property (readwrite, copy, nonnull, nonatomic) NSArray<RSCrashReporterError *> *errors;

/**
 *  Customized hash for grouping this report with other errors
 */
@property (readwrite, copy, nullable, nonatomic) NSString *groupingHash;
/**
 *  Breadcrumbs from user events leading up to the error
 */
@property (readwrite, copy, nonnull, nonatomic) NSArray<RSCrashReporterBreadcrumb *> *breadcrumbs;

/**
 * Feature flags that were active when the error occurred
 */
@property (readonly, strong, nonnull, nonatomic) NSArray<RSCrashReporterFeatureFlag *> *featureFlags;

/**
 * A per-event override for the apiKey.
 * - The default value of nil results in the RSCrashReporterConfiguration apiKey being used.
 * - Writes are not persisted to RSCrashReporterConfiguration.
 */
@property (readwrite, copy, nullable, nonatomic) NSString *apiKey;

/**
 *  Device information such as OS name and version
 */
@property (readonly, nonnull, nonatomic) RSCrashReporterDeviceWithState *device;

/**
 *  App information such as the name, version, and bundle ID
 */
@property (readonly, nonnull, nonatomic) RSCrashReporterAppWithState *app;

/**
 * Whether the event was a crash (i.e. unhandled) or handled error in which the system
 * continued running.
 */
@property (readwrite, nonatomic) BOOL unhandled;

/**
 * Thread traces for the error that occurred, if collection was enabled.
 */
@property (readwrite, copy, nonnull, nonatomic) NSArray<RSCrashReporterThread *> *threads;

/**
 * The original object that caused the error in your application. This value will only be populated for
 * non-fatal errors which did not terminate the process, and will contain an NSError or NSException.
 *
 * Manipulating this field does not affect the error information reported to the
 * RSCrashReporter dashboard. Use event.errors to access and amend the representation of
 * the error that will be sent.
 */
@property (strong, nullable, nonatomic) id originalError;


// =============================================================================
// MARK: - User
// =============================================================================

/**
 * The current user
 */
//@property (readonly, nonnull, nonatomic) RSCrashReporterUser *user;

/**
 *  Set user metadata
 *
 *  @param userId ID of the user
 *  @param name   Name of the user
 *  @param email  Email address of the user
 */
- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name;

@end

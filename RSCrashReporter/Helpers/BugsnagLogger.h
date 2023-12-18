/**
 * Higher-level user-accessible RSCrashReporter logging configuration.  Controls how
 * verbose the internal RSCrashReporter logging is.  Not related to logging Events or
 * other errors with the RSCrashReporter server.
 *
 * Users can configure a custom logging level in their app as follows:
 *
 * When using Cocoapods to install RSCrashReporter you can add a `post-install` section
 * to the Podfile:
 *
 *     post_install do |rep|
 *         rep.pods_project.targets.each do |target|
 *             if target.name == "RSCrashReporter"
 *                 target.build_configurations.each do |config|
 *                     config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'RSC_LOG_LEVEL=RSC_LOGLEVEL_INFO']
 *                 end
 *             end
 *         end
 *     end
 *
 * Change the value of `RSC_LOG_LEVEL` to one of the levels given below and run `pod install`.
 *
 * Note: There is also lower-level KSCrash logging configuration in RSC_KSLogger.h
 *       That file includes this one.  No further configuration is required.
 */

#define RSC_LOGLEVEL_NONE 0
#define RSC_LOGLEVEL_ERR 10
#define RSC_LOGLEVEL_WARN 20
#define RSC_LOGLEVEL_INFO 30
#define RSC_LOGLEVEL_DEBUG 40
#define RSC_LOGLEVEL_TRACE 50

#ifndef RSC_LOG_LEVEL
#define RSC_LOG_LEVEL RSC_LOGLEVEL_INFO
#endif

#ifdef __OBJC__

#import <Foundation/Foundation.h>

#if RSC_LOG_LEVEL >= RSC_LOGLEVEL_ERR
#define rsc_log_err(...) NSLog(@"[RSCrashReporter] [ERROR] " __VA_ARGS__)
#else
#define rsc_log_err(format, ...)
#endif

#if RSC_LOG_LEVEL >= RSC_LOGLEVEL_WARN
#define rsc_log_warn(...) NSLog(@"[RSCrashReporter] [WARN] " __VA_ARGS__)
#else
#define rsc_log_warn(format, ...)
#endif

#if RSC_LOG_LEVEL >= RSC_LOGLEVEL_INFO
#define rsc_log_info(...) NSLog(@"[RSCrashReporter] [INFO] " __VA_ARGS__)
#else
#define rsc_log_info(format, ...)
#endif

#if RSC_LOG_LEVEL >= RSC_LOGLEVEL_DEBUG
#define rsc_log_debug(...) NSLog(@"[RSCrashReporter] [DEBUG] " __VA_ARGS__)
#else
#define rsc_log_debug(format, ...)
#endif

#endif

#import "RSC_KSCrashIdentifier.h"

#import "RSC_KSCrash.h"

#import <Foundation/Foundation.h>

#include <stdio.h>
#include <string.h>

static char *report_directory;

void rsc_kscrash_generate_report_initialize(const char *directory) {
    report_directory = directory ? strdup(directory) : NULL;
}

char *rsc_kscrash_generate_report_path(const char *identifier, bool is_recrash_report) {
    if (identifier == NULL) {
        return NULL;
    }
    char *type = is_recrash_report ? "RecrashReport" : "CrashReport";
    char *path = NULL;
    asprintf(&path, "%s/%s-%s.json", report_directory, type, identifier);
    return path;
}

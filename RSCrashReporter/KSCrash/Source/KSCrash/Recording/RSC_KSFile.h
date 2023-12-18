//
//  RSC_KSFile.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 12/01/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#pragma once

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    int fd;
    char *buffer;
    size_t bufferSize;
    size_t bufferUsed;
} RSC_KSFile;

void RSC_KSFileInit(RSC_KSFile *file, int fd, char *buffer, size_t length);

bool RSC_KSFileWrite(RSC_KSFile *file, const char *data, size_t length);

bool RSC_KSFileFlush(RSC_KSFile *file);

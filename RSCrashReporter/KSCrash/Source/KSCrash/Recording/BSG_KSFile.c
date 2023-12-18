//
//  RSC_KSFile.c
//  RSCrashReporter
//
//  Created by Nick Dowell on 12/01/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#include "RSC_KSFile.h"

#include "RSC_KSFileUtils.h"

#include <string.h>
#include <sys/param.h>

static inline bool rsc_write(const int fd, const char *bytes, size_t length) {
    return rsc_ksfuwriteBytesToFD(fd, bytes, (ssize_t)length);
}

void RSC_KSFileInit(RSC_KSFile *file, int fd, char *buffer, size_t length) {
    file->fd = fd;
    file->buffer = buffer;
    file->bufferSize = length;
    file->bufferUsed = 0;
}

bool RSC_KSFileWrite(RSC_KSFile *file, const char *data, size_t length) {
    const size_t bytesCopied = MIN(file->bufferSize - file->bufferUsed, length);
    memcpy(file->buffer + file->bufferUsed, data, bytesCopied);
    file->bufferUsed += bytesCopied;
    data += bytesCopied;
    length -= bytesCopied;
    
    if (file->bufferUsed == file->bufferSize) {
        if (!RSC_KSFileFlush(file)) {
            return false;
        }
    }
    
    if (!length) {
        return true;
    }
    
    if (length >= file->bufferSize) {
        return rsc_write(file->fd, data, length);
    }
    
    memcpy(file->buffer, data, length);
    file->bufferUsed = length;
    return true;
}

bool RSC_KSFileFlush(RSC_KSFile *file) {
    if (!rsc_write(file->fd, file->buffer, file->bufferUsed)) {
        return false;
    }
    file->bufferUsed = 0;
    return true;
}

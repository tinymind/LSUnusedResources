//
//  FileUtils.m
//  LSUnusedResources
//
//  Created by jhgfer on 16/4/25.
//  Copyright © 2016年 lessfun.com. All rights reserved.
//

#import "FileUtils.h"

@implementation FileUtils

+ (uint64_t)fileSizeAtPath:(NSString *)path isDir:(BOOL *)isDir {
    uint64_t size = 0L;
    NSError *error = nil;
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (!error) {
        *isDir = [attr[NSFileType] isEqualToString:NSFileTypeDirectory];
        if (!*isDir) {
            size = [attr[NSFileSize] unsignedLongLongValue];
        } else {
            size = [self folderSizeAtPath:path];
        }
    }
    return size;
}

+ (uint64_t)folderSizeAtPath:(NSString *)path {
    uint64_t totalFileSize = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    for (NSString *fileName in fileEnumerator) {
        NSString *filePath = [path stringByAppendingPathComponent:fileName];
        NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        totalFileSize += fileAttrs.fileSize;
    }
    return totalFileSize;
}

@end

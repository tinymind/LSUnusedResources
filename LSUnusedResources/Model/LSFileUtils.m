//
//  LSFileUtils.m
//  LSUnusedResources
//
//  Created by jhgfer on 16/4/25.
//  Copyright © 2016年 lessfun.com. All rights reserved.
//

#import "LSFileUtils.h"

@implementation LSFileUtils
+ (uint64_t)fileSizeAtPath:(NSString *)path isDir:(BOOL *)isDir {
    uint64_t size = 0L;
    NSError *error = nil;
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (!error) {
        *isDir = [attr[NSFileType]isEqualToString:NSFileTypeDirectory];
        if (!*isDir) {
            size = [attr[NSFileSize] unsignedLongLongValue];
        }
    }
    return size;
}

@end

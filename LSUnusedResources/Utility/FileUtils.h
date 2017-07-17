//
//  FileUtils.h
//  LSUnusedResources
//
//  Created by jhgfer on 16/4/25.
//  Copyright © 2016年 lessfun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileUtils : NSObject
/**
 *  get file size, contain directory
 *  @param path  path
 *  @param isDir
 *
 *  @return
 */
+ (uint64_t)fileSizeAtPath:(NSString *)path isDir:(BOOL *)isDir;

+ (uint64_t)folderSizeAtPath:(NSString *)path;

@end

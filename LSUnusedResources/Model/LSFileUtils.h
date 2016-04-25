//
//  LSFileUtils.h
//  LSUnusedResources
//
//  Created by jhgfer on 16/4/25.
//  Copyright © 2016年 lessfun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LSFileUtils : NSObject
/**
 *  get file size, ignore directory
 *  @param path  path
 *  @param isDir
 *
 *  @return
 */
+ (uint64_t)fileSizeAtPath:(NSString *)path isDir:(BOOL *)isDir;
@end

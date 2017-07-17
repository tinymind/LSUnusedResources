//
//  StringUtils.h
//  LSUnusedResources
//
//  Created by lslin on 15/9/1.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StringUtils : NSObject

+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str;

+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str suffix:(NSString *)suffix;

+ (BOOL)isImageTypeWithName:(NSString *)name;

@end

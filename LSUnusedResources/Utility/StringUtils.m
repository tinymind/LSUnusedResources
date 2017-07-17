//
//  StringUtils.m
//  LSUnusedResources
//
//  Created by lslin on 15/9/1.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import "StringUtils.h"

static NSString * const kSuffix2x = @"@2x";
static NSString * const kSuffix3x = @"@3x";

@implementation StringUtils

+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str {
    NSString *suffix = [str pathExtension];
    return [self stringByRemoveResourceSuffix:str suffix:suffix];
}

+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str suffix:(NSString *)suffix {
    NSString *keyName = str;
    
    if (suffix.length && [keyName hasSuffix:suffix]) {
        keyName = [keyName stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", suffix] withString:@""];
    }
    if ([keyName hasSuffix:kSuffix2x]) {
        keyName = [keyName stringByReplacingOccurrencesOfString:kSuffix2x withString:@""];
    } else if ([keyName hasSuffix:kSuffix3x]) {
        keyName = [keyName stringByReplacingOccurrencesOfString:kSuffix3x withString:@""];
    }
    return keyName;
}

+ (BOOL)isImageTypeWithName:(NSString *)name {
    static NSArray *imageSuffixs = nil;
    
    if (!imageSuffixs) {
        imageSuffixs = @[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"pdf"];
    }
    
    NSString *ext = [[name pathExtension] lowercaseString];
    if (ext.length && [imageSuffixs containsObject:ext]) {
        return YES;
    }
    return NO;
}

@end

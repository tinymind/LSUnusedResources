//
//  RecourseStringSearcher.h
//  LSUnusedResources
//
//  Created by lslin on 15/8/31.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kNotificationResourceStringQueryDone;


@interface ResourceStringSearcher : NSObject

@property (strong, nonatomic, readonly) NSMutableSet *resStringSet;

+ (instancetype)sharedObject;

- (void)startWithProjectPath:(NSString *)projectPath fileSuffixs:(NSArray *)fileSuffixs;
- (void)reset;

- (BOOL)containResourceName:(NSString *)name;

@end

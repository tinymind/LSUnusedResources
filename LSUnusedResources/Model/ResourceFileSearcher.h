//
//  ResourceFileSearcher.h
//  LSUnusedResources
//
//  Created by lslin on 15/8/31.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

extern NSString * const kNotificationResourceFileQueryDone;


@interface ResourceFileInfo : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *path;
@property (assign, nonatomic) BOOL isDir;
@property (assign, nonatomic) uint64_t fileSize;

- (NSImage *)image;

@end


@interface ResourceFileSearcher : NSObject

@property (strong, nonatomic, readonly) NSMutableDictionary *resNameInfoDict;/**< dict<NSString *name, ResourceFileInfo *info> */

+ (instancetype)sharedObject;

- (void)startWithProjectPath:(NSString *)projectPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)resourceSuffixs;

- (void)reset;

- (BOOL)isImageSetFolder:(NSString *)folder;

@end

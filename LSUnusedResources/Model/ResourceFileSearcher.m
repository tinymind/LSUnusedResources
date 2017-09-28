//
//  ResourceFileSearcher.m
//  LSUnusedResources
//
//  Created by lslin on 15/8/31.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import "ResourceFileSearcher.h"
#import "StringUtils.h"
#import "FileUtils.h"

NSString * const kNotificationResourceFileQueryDone = @"kNotificationResourceFileQueryDone";

static NSString * const kSuffixImageSet    = @".imageset";
static NSString * const kSuffixLaunchImage = @".launchimage";
static NSString * const kSuffixAppIcon     = @".appiconset";
static NSString * const kSuffixBundle      = @".bundle";
static NSString * const kSuffixPng         = @".png";


@implementation ResourceFileInfo

- (NSImage *)image {
    if ([StringUtils isImageTypeWithName:self.name]) {
        return [[NSImage alloc] initByReferencingFile:self.path];
    }
    
    if ([[ResourceFileSearcher sharedObject] isImageSetFolder:self.name]) {
        NSError *error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
        if (files.count == 0) {
            return nil;
        }
        for (NSString *file in files) {
            if ([StringUtils isImageTypeWithName:file]) {
                return [[NSImage alloc] initByReferencingFile:[self.path stringByAppendingPathComponent:file]];
            }
        }
    }
    
    return nil;
}

@end


@interface ResourceFileSearcher ()

@property (assign, nonatomic) BOOL isRunning;
@property (strong, nonatomic) NSMutableDictionary *resNameInfoDict;
@end


@implementation ResourceFileSearcher

+ (instancetype)sharedObject {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}


- (void)startWithProjectPath:(NSString *)projectPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)resourceSuffixs {
    if (self.isRunning) {
        return;
    }
    if (projectPath.length == 0 || resourceSuffixs.count == 0) {
        return;
    }
    
    self.isRunning = YES;
    
    [self scanResourceFileWithProjectPath:projectPath excludeFolders:excludeFolders resourceSuffixs:resourceSuffixs];
}

- (void)reset {
    self.isRunning = NO;
    [self.resNameInfoDict removeAllObjects];
}

- (BOOL)isImageSetFolder:(NSString *)folder
{
    if ([folder hasSuffix:kSuffixImageSet]
        || [folder hasSuffix:kSuffixAppIcon]
        || [folder hasSuffix:kSuffixLaunchImage]) {
        return YES;
    }
    return NO;
}

- (BOOL)isInImageSetFolder:(NSString *)folder
{
    if (![self isImageSetFolder:folder]
        && ([folder rangeOfString:kSuffixImageSet].location != NSNotFound
        || [folder rangeOfString:kSuffixAppIcon].location != NSNotFound
        || [folder rangeOfString:kSuffixLaunchImage].location != NSNotFound)) {
        return YES;
    }
    return NO;
}

#pragma mark - Private

- (void)scanResourceFileWithProjectPath:(NSString *)projectPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)resourceSuffixs {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *resPaths = [self resourceFilesInDirectory:projectPath excludeFolders:excludeFolders resourceSuffixs:resourceSuffixs];
        
        NSMutableDictionary *tempResNameInfoDict = [NSMutableDictionary dictionary];
        for (NSString *path in resPaths) {
            NSString *name = [path lastPathComponent];
            if (!name.length) {
                continue;
            }
            
            NSString *keyName = [StringUtils stringByRemoveResourceSuffix:name];

            if (!tempResNameInfoDict[keyName]) {
                BOOL isDir = NO;
                ResourceFileInfo *info = [ResourceFileInfo new];
                info.name = name;
                info.path = path;
                info.fileSize = [FileUtils fileSizeAtPath:path isDir:&isDir];
                info.isDir = isDir;
                tempResNameInfoDict[keyName] = info;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resNameInfoDict = tempResNameInfoDict;
            self.isRunning = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResourceFileQueryDone object:nil userInfo:nil];
        });
    });
}

- (NSArray *)resourceFilesInDirectory:(NSString *)directoryPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)suffixs {
    
    NSMutableArray *resources = [NSMutableArray array];
    
    for (NSString *fileType in suffixs) {
        // list of path<NSString>
        NSArray *pathList = [self searchDirectory:directoryPath excludeFolders:excludeFolders forFiletype:fileType];
        if (pathList.count) {
            for (NSString *path in pathList) {
                // ignore if the resource file is in xxx/xxx.imageset/; xx/LaunchImage.launchimage; xx/AppIcon.appiconset; xx.bundle/xx
                if (![self isInImageSetFolder:path]
                    && [path rangeOfString:kSuffixBundle].location == NSNotFound) {
                    [resources addObject:path];
                }
            }
        }
    }
    
//    // list of path<NSString>
//    NSArray *pathList = [self searchDirectory:directoryPath excludeFolders:excludeFolders forFiletypes:suffixs];
//    if (pathList.count) {
//        for (NSString *path in pathList) {
//            // if the resource file is not in xxx/xxx.imageset/; xx/LaunchImage.launchimage; xx/AppIcon.appiconset
//            if (![path hasPrefix:kSuffixPng]) {
//                [resources addObjectsFromArray:pathList];
//            } else if (![self isImageSetFolder:path]
//                && [path rangeOfString:kSuffixBundle].location == NSNotFound) {
//                [resources addObject:path];
//            }
//        }
//    }
    
    return resources;
}

- (NSArray *)searchDirectory:(NSString *)directoryPath excludeFolders:(NSArray *)excludeFolders forFiletype:(NSString *)filetype {
    // Create a find task
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/find"];
    
    // Search for all files
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:directoryPath];
    [argvals addObject:@"-name"];
    [argvals addObject:[NSString stringWithFormat:@"*.%@", filetype]];
    
    for (NSString *folder in excludeFolders) {
        [argvals addObject:@"!"];
        [argvals addObject:@"-path"];
        [argvals addObject:[NSString stringWithFormat:@"*/%@/*", folder]];
    }
    
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // See if we can create a lines array
    if (string.length) {
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        return lines;
    }
    return nil;
}

// Toooooo Sloooooow
- (NSArray *)searchDirectory:(NSString *)directoryPath excludeFolders:(NSArray *)excludeFolders forFiletypes:(NSArray *)filetypes {
    // find -E . -iregex ".*\.(html|plist)" ! -path "*/Movies/*" ! -path "*/Downloads/*" ! -path "*/Music/*"
    // Create a find task
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/find"];
    
    // Search for all files
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:@"-E"];
    [argvals addObject:directoryPath];
    [argvals addObject:@"-iregex"];
    
    [argvals addObject:[NSString stringWithFormat:@".*\\.(%@)", [filetypes componentsJoinedByString:@"|"]]];
    
    for (NSString *folder in excludeFolders) {
        [argvals addObject:@"!"];
        [argvals addObject:@"-path"];
        [argvals addObject:[NSString stringWithFormat:@"*/%@/*", folder]];
    }
    
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // See if we can create a lines array
    if (string.length) {
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        return lines;
    }
    return nil;
}

@end

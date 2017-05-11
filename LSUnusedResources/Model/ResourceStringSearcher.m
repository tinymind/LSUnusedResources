//
//  RecourseStringSearcher.m
//  LSUnusedResources
//
//  Created by lslin on 15/8/31.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import "ResourceStringSearcher.h"
#import "StringUtils.h"

NSString * const kNotificationResourceStringQueryDone = @"kNotificationResourceStringQueryDone";

typedef NS_ENUM(NSUInteger, LSFileType) {
    LSFileTypeNone   = 0,
    LSFileTypeH      = 1,
    LSFileTypeObjC   = 2,
    LSFileTypeC      = 3,
    LSFileTypeSwift  = 4,
    LSFileTypeHtml   = 5,
    LSFileTypeCSS    = 6,
    LSFileTypeXib    = 7,
    LSFileTypePlist  = 8,
    LSFileTypeJson   = 9,
    LSFileTypeJs     = 10,
    LSFileTypeStings = 11
};


@interface ResourceStringSearcher ()

@property (strong, nonatomic) NSMutableSet *resStringSet;
@property (strong, nonatomic) NSString *projectPath;
@property (strong, nonatomic) NSArray *resSuffixs;
@property (strong, nonatomic) NSArray *fileSuffixs;
@property (strong, nonatomic) NSArray *excludeFolders;
@property (assign, nonatomic) BOOL isRunning;

@end


@implementation ResourceStringSearcher

+ (instancetype)sharedObject {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (void)startWithProjectPath:(NSString *)projectPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)resourceSuffixs fileSuffixs:(NSArray *)fileSuffixs {
    if (self.isRunning) {
        return;
    }
    if (projectPath.length == 0 || fileSuffixs.count == 0) {
        return;
    }
    
    self.isRunning = YES;
    self.projectPath = projectPath;
    self.resSuffixs = resourceSuffixs;
    self.fileSuffixs = fileSuffixs;
    self.excludeFolders = excludeFolders;
    
    [self runSearchTask];
}

- (void)reset {
    self.isRunning = NO;
    [self.resStringSet removeAllObjects];
}

- (BOOL)containsResourceName:(NSString *)name {
    if ([self.resStringSet containsObject:name]) {
        return YES;
    } else {
        if ([name pathExtension]) {
            NSString *nameWithoutSuffix = [StringUtils stringByRemoveResourceSuffix:name];
            return [self.resStringSet containsObject:nameWithoutSuffix];
        }
    }
    return NO;
}

- (BOOL)containsSimilarResourceName:(NSString *)name {
    NSString *regexStr = @"(\\d+)";
    NSRegularExpression* regexExpression = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray* matchs = [regexExpression matchesInString:name options:0 range:NSMakeRange(0, name.length)];
    if (matchs != nil && [matchs count] == 1) {
        NSTextCheckingResult *checkingResult = [matchs objectAtIndex:0];
        NSRange numberRange = [checkingResult rangeAtIndex:1];
        
        NSString *prefix = nil;
        NSString *suffix = nil;
        
        BOOL hasSamePrefix = NO;
        BOOL hasSameSuffix = NO;
        
        if (numberRange.location != 0) {
            prefix = [name substringToIndex:numberRange.location];
        } else {
            hasSamePrefix = YES;
        }
        
        if (numberRange.location + numberRange.length < name.length) {
            suffix = [name substringFromIndex:numberRange.location + numberRange.length];
        } else {
            hasSameSuffix = YES;
        }
        
        for (NSString *res in self.resStringSet) {
            if (hasSameSuffix && !hasSamePrefix) {
                if ([res hasPrefix:prefix]) {
                    return YES;
                }
            }
            if (hasSamePrefix && !hasSameSuffix) {
                if ([res hasSuffix:suffix]) {
                    return YES;
                }
            }
            if (!hasSamePrefix && !hasSameSuffix) {
                if ([res hasPrefix:prefix] && [res hasSuffix:suffix]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

#pragma mark - Private

- (void)runSearchTask {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.resStringSet = [NSMutableSet set];
        [self handleFilesAtPath:self.projectPath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRunning = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResourceStringQueryDone object:nil userInfo:nil];
        });
    });
}

- (BOOL)handleFilesAtPath:(NSString *)dir
{
    // Get all the files at dir
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&error];
    if (files.count == 0) {
        return NO;
    }
    
    for (NSString *file in files) {
        if ([file hasPrefix:@"."]) {
            continue;
        }
        if ([self.excludeFolders containsObject:file]) {
            continue;
        }
        
        NSString *tempPath = [dir stringByAppendingPathComponent:file];
        if ([self isDirectory:tempPath]) {
            [self handleFilesAtPath:tempPath];
        } else {
            LSFileType fileType = [self fileTypeByName:file];
            if (fileType == LSFileTypeNone) {
                continue;
            } else {
                [self parseFileAtPath:tempPath withType:fileType];
            }
        }
    }
    return YES;
}

- (void)parseFileAtPath:(NSString *)path withType:(LSFileType)fileType {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content) {
        return;
    }
    
    NSString *pattern = nil;
    NSInteger groupIndex = -1;
    switch (fileType) {
        case LSFileTypeObjC:
            pattern = @"@\"(.+?)\"";//@"imageNamed:@\"(.+)\"";//or: (imageNamed|contentOfFile):@\"(.*)\" // http://www.raywenderlich.com/30288/nsregularexpression-tutorial-and-cheat-sheet
            groupIndex = 1;
            break;
        case LSFileTypeSwift:
            pattern = @"\"(.+?)\"";//@"named:\\s*\"(.+?)\"";//UIImage(named:"xx") or UIImage(named: "xx")
            groupIndex = 1;
            break;
        case LSFileTypeXib:
            pattern = @"image name=\"(.+?)\"";//image name="xx"
            groupIndex = 1;
            break;
        case LSFileTypeHtml:
            pattern = @"img\\s+src=[\"\'](.+?)[\"\']";//<img src="xx"> <img src='xx'>
            groupIndex = 1;
            break;
        case LSFileTypeJs:
            pattern = @"[\"\']src[\"\'],\\s+[\"\'](.+?)[\"\']";// "src", "xx"> 'src', 'xx'>
            groupIndex = 1;
            break;
        case LSFileTypeJson:
            pattern = @":\\s+\"(.+?)\"";//"xx"
            groupIndex = 1;
            break;
        case LSFileTypePlist:
            pattern = @">(.+?)<";//"<string>xx</string>"
            groupIndex = 1;
            break;
        case LSFileTypeCSS:
        case LSFileTypeH:
        case LSFileTypeC:
            pattern = [NSString stringWithFormat:@"([a-zA-Z0-9_-]+)\\.(%@)", self.resSuffixs.count ? [self.resSuffixs componentsJoinedByString:@"|"] : @"png|gif|jpg|jpeg"]; //*.(png|gif|jpg|jpeg)
            groupIndex = 1;
            break;
        case LSFileTypeStings:
            pattern = @"=\\s*\"(.+)\"\\s*;";
            groupIndex = 1;
            break;
        default:
            break;
    }
    if (pattern && groupIndex >= 0) {
        NSArray *list = [self getMatchStringWithContent:content pattern:pattern groupIndex:groupIndex];
        [self.resStringSet addObjectsFromArray:list];
    }
}

- (NSArray *)getMatchStringWithContent:(NSString *)content pattern:(NSString*)pattern groupIndex:(NSInteger)index
{
    NSRegularExpression* regexExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray* matchs = [regexExpression matchesInString:content options:0 range:NSMakeRange(0, content.length)];
    
    if (matchs.count) {
        NSMutableArray *list = [NSMutableArray array];
        for (NSTextCheckingResult *checkingResult in matchs) {
            NSString *res = [content substringWithRange:[checkingResult rangeAtIndex:index]];
            res = [res lastPathComponent];
            res = [StringUtils stringByRemoveResourceSuffix:res];
            [list addObject:res];
        }
        return list;
    }
    
    return nil;
}

- (BOOL)isDirectory:(NSString *)path {
    BOOL isDirectory;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
}

- (LSFileType)fileTypeByName:(NSString *)name {
    NSString *ext = [[name pathExtension] lowercaseString];
    if (![self.fileSuffixs containsObject:ext]) {
        return LSFileTypeNone;
    }
    if ([ext isEqualTo:@"m"] || [ext isEqualTo:@"mm"]) {
        return LSFileTypeObjC;
    }
    if ([ext isEqualTo:@"xib"] || [ext isEqualTo:@"storyboard"]) {
        return LSFileTypeXib;
    }
    if ([ext isEqualTo:@"plist"]) {
        return LSFileTypePlist;
    }
    if ([ext isEqualTo:@"swift"]) {
        return LSFileTypeSwift;
    }
    if ([ext isEqualTo:@"h"]) {
        return LSFileTypeH;
    }
    if ([ext isEqualTo:@"c"] || [ext isEqualTo:@"cpp"]) {
        return LSFileTypeC;
    }
    if ([ext isEqualTo:@"html"]) {
        return LSFileTypeHtml;
    }
    if ([ext isEqualTo:@"json"]) {
        return LSFileTypeJson;
    }
    if ([ext isEqualTo:@"js"]) {
        return LSFileTypeJs;
    }
    if ([ext isEqualTo:@"css"]) {
        return LSFileTypeCSS;
    }
    if ([ext isEqualTo:@"strings"]) {
        return LSFileTypeStings;
    }
    
    return LSFileTypeNone;
}

//- (NSArray *)resourceStringsInDirectory:(NSString *)directoryPath fileTypes:(NSArray *)fileTypes {
//    // Create a find task
//    NSTask *task = [[NSTask alloc] init];
//    [task setLaunchPath: @"/usr/bin/grep"];
//    
//    // http://stackoverflow.com/questions/221921/use-grep-exclude-include-syntax-to-not-grep-through-certain-files
//    // grep -ri --include="\*.{cpp,h}" pattern rootdir
//    // http://stackoverflow.com/questions/10619160/how-do-i-use-the-grep-include-option-for-multiple-file-types
//    // grep -r --include=*.html --include=*.php --include=*.htm "pattern" /some/path/
//    NSString *includeFiles = [fileTypes componentsJoinedByString:@" --include=*."];
//    NSString *pattern = @"imageNamed:@\".*\"";
//    
//    // Search for all res files
//    // -r (recursive) -i (ignore-case) --include (search only files that match the file pattern)
//    // -o    Print each match, but only the match, not the entire line.
//    // -h    Never print filename headers (i.e. filenames) with output lines.
//    NSArray *argvals = @[@"-rioh",
//                         includeFiles,
//                         pattern,
//                         directoryPath
//                        ];
//    [task setArguments: argvals];
//    
//    NSPipe *pipe = [NSPipe pipe];
//    [task setStandardOutput: pipe];
//    NSFileHandle *file = [pipe fileHandleForReading];
//    
//    // Run task
//    [task launch];
//    
//    // Read the response
//    NSData *data = [file readDataToEndOfFile];
//    NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
//    
//    // See if we can create a lines array
//    NSArray *lines = [string componentsSeparatedByString:@"\n"];
//    
//    return lines;
//}

@end

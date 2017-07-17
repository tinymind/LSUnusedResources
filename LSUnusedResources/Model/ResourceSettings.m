//
//  ResourceSettings.m
//  LSUnusedResources
//
//  Created by lslin on 2017/7/12.
//  Copyright © 2017年 lessfun.com. All rights reserved.
//

#import "ResourceSettings.h"

static NSString * const kSettingsKeyProjectPath      = @"ProjectPath";
static NSString * const kSettingsKeyExcludeFolders   = @"ExcludeFolders";
static NSString * const kSettingsKeyResourceSuffixs  = @"ResourceSuffixs";
static NSString * const kSettingsKeyResourcePatterns = @"ResourcePatterns";
static NSString * const kSettingsKeyMatchSimilarName = @"MatchSimilarName";

#pragma mark - ResourceSettings

@interface ResourceSettings ()

@end

@implementation ResourceSettings

+ (instancetype)sharedObject {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _projectPath = [self getValueForKey:kSettingsKeyProjectPath];
        _excludeFolders = [self getValueForKey:kSettingsKeyExcludeFolders];
        _resourceSuffixs = [self getValueForKey:kSettingsKeyResourceSuffixs];
        _resourcePatterns = [self getValueForKey:kSettingsKeyResourcePatterns];
        _matchSimilarName = [self getValueForKey:kSettingsKeyMatchSimilarName];
    }
    return self;
}

#pragma mark - Public

- (void)updateResourcePatternAtIndex:(NSInteger)index withObject:(id)obj forKey:(NSString *)key {
    NSMutableArray *patterns = [NSMutableArray arrayWithArray:self.resourcePatterns];
    if (obj && patterns.count && index < patterns.count) {
        NSMutableDictionary *pattern = [NSMutableDictionary dictionaryWithDictionary:[patterns objectAtIndex:index]];
        [pattern setObject:obj forKey:key];
        [patterns replaceObjectAtIndex:index withObject:[pattern copy]];
        self.resourcePatterns = patterns;
    }
}

- (void)addResourcePattern:(NSDictionary *)pattern {
    if (pattern) {
        NSMutableArray *patterns = [NSMutableArray arrayWithArray:self.resourcePatterns];
        [patterns insertObject:pattern atIndex:0];
        self.resourcePatterns = patterns;
    }
}

- (void)removeResourcePatternAtIndex:(NSInteger)index {
    NSMutableArray *patterns = [NSMutableArray arrayWithArray:self.resourcePatterns];
    if (patterns.count && index < patterns.count) {
        [patterns removeObjectAtIndex:index];
        self.resourcePatterns = patterns;
    }
}

#pragma mark - Property

- (void)setProjectPath:(NSString *)projectPath {
    _projectPath = projectPath;
    [self setValue:projectPath forKey:kSettingsKeyProjectPath];
}

- (void)setExcludeFolders:(NSArray *)excludeFolders {
    _excludeFolders = excludeFolders;
    [self setValue:excludeFolders forKey:kSettingsKeyExcludeFolders];
}

- (void)setResourceSuffixs:(NSArray *)resourceSuffixs {
    _resourceSuffixs = resourceSuffixs;
    [self setValue:resourceSuffixs forKey:kSettingsKeyResourceSuffixs];
}

- (void)setResourcePatterns:(NSArray *)resourcePatterns {
    _resourcePatterns = resourcePatterns;
    [self setValue:resourcePatterns forKey:kSettingsKeyResourcePatterns];
}

- (void)setMatchSimilarName:(NSNumber *)matchSimilarName {
    _matchSimilarName = matchSimilarName;
    [self setValue:matchSimilarName forKey:kSettingsKeyMatchSimilarName];
}

#pragma mark - Private

- (id)getValueForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if (!value || !key) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)removeValueForKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

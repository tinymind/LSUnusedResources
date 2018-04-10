//
//  MainViewController.m
//  LSUnusedResources
//
//  Created by lslin on 15/8/31.
//  Copyright (c) 2015年 lessfun.com. All rights reserved.
//

#import "MainViewController.h"
#import "ResourceFileSearcher.h"
#import "ResourceStringSearcher.h"
#import "StringUtils.h"
#import "ResourceSettings.h"

// Constant strings
static NSString * const kDefaultResourceSuffixs    = @"imageset|jpg|gif|png";
static NSString * const kDefaultResourceSeparator  = @"|";

static NSString * const kResultIdentifyFileIcon    = @"FileIcon";
static NSString * const kResultIdentifyFileName    = @"FileName";
static NSString * const kResultIdentifyFileSize    = @"FileSize";
static NSString * const kResultIdentifyFilePath    = @"FilePath";

@interface MainViewController () <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

// Project
@property (weak) IBOutlet NSButton *browseButton;
@property (weak) IBOutlet NSTextField *pathTextField;
@property (weak) IBOutlet NSTextField *excludeFolderTextField;

// Settings
@property (weak) IBOutlet NSTextField *resSuffixTextField;

@property (weak) IBOutlet NSTableView *patternTableView;

@property (weak) IBOutlet NSButton *ignoreSimilarCheckbox;

// Result
@property (weak) IBOutlet NSTableView *resultsTableView;
@property (weak) IBOutlet NSProgressIndicator *processIndicator;
@property (weak) IBOutlet NSTextField *statusLabel;

@property (weak) IBOutlet NSButton *searchButton;
@property (weak) IBOutlet NSButton *exportButton;
@property (weak) IBOutlet NSButton *deleteButton;

@property (strong, nonatomic) NSMutableArray *unusedResults;
@property (assign, nonatomic) BOOL isFileDone;
@property (assign, nonatomic) BOOL isStringDone;
@property (strong, nonatomic) NSDate *startTime;
@property (assign, nonatomic) BOOL isSortDescByFileSize;

@end

@implementation MainViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    [self setupSettings];
    
    // Setup tableview click action
    [self.resultsTableView setAction:@selector(onResultsTableViewSingleClicked)];
    [self.resultsTableView setDoubleAction:@selector(onResultsTableViewDoubleClicked)];
    self.resultsTableView.allowsEmptySelection = YES;
    self.resultsTableView.allowsMultipleSelection = YES;
    
    self.patternTableView.allowsEmptySelection = YES;
    self.patternTableView.allowsMultipleSelection = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResourceFileQueryDone:) name:kNotificationResourceFileQueryDone object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResourceStringQueryDone:) name:kNotificationResourceStringQueryDone object:nil];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - Action

- (IBAction)onBrowseButtonClicked:(id)sender {
    // Show an open panel
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        // Update the path text field
        NSString *path = [[openPanel URL] path];
        [ResourceSettings sharedObject].projectPath = path;
        [self.pathTextField setStringValue:path];
    }
}

- (IBAction)onSearchButtonClicked:(id)sender {
    // Check if user has selected or entered a path
    NSString *projectPath = self.pathTextField.stringValue;
    if (!projectPath.length) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"Path Error" subtitle:@"Project path is empty"];
        return;
    }
    
    // Check the path exists
    BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:projectPath];
    if (!pathExists) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"Path Error" subtitle:@"Project folder is not exists"];
        return;
    }
    
    self.startTime = [NSDate date];
    
    // Reset
    [[ResourceFileSearcher sharedObject] reset];
    [[ResourceStringSearcher sharedObject] reset];
    
    [self.unusedResults removeAllObjects];
    [self.resultsTableView reloadData];
    
    self.isFileDone = NO;
    self.isStringDone = NO;
    
    NSArray *resourceSuffixs = [self resourceSuffixs];
    if (!self.resourceSuffixs.count) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"Suffix Error" subtitle:@"Resource suffix is invalid"];
        return ;
    }

    NSArray *excludeFolders = [ResourceSettings sharedObject].excludeFolders;
    
    [[ResourceFileSearcher sharedObject] startWithProjectPath:projectPath excludeFolders:excludeFolders resourceSuffixs:resourceSuffixs];
    
    [[ResourceStringSearcher sharedObject] startWithProjectPath:projectPath excludeFolders:excludeFolders resourceSuffixs:resourceSuffixs resourcePatterns:[self resourcePatterns]];
    
    [self setUIEnabled:NO];
}

- (IBAction)onExportButtonClicked:(id)sender {
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
    
    BOOL okButtonPressed = ([save runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        NSString *selectedFile = [[save URL] path];
        
        NSMutableString *outputResults = [[NSMutableString alloc] init];
        NSString *projectPath = [self.pathTextField stringValue];
        [outputResults appendFormat:@"Unused Resources In Project: \n%@\n\n", projectPath];
        
        for (ResourceFileInfo *info in self.unusedResults) {
            [outputResults appendFormat:@"%@\n", info.path];
        }
        
        // Output
        NSError *writeError = nil;
        [outputResults writeToFile:selectedFile atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        
        // Check write result
        if (writeError == nil) {
            [self showAlertWithStyle:NSInformationalAlertStyle title:@"Export Complete" subtitle:[NSString stringWithFormat:@"Export Complete: %@", selectedFile]];
        } else {
            [self showAlertWithStyle:NSCriticalAlertStyle title:@"Export Error" subtitle:[NSString stringWithFormat:@"Export Error: %@", writeError]];
        }
    }
}

- (IBAction)onDeleteButtonClicked:(id)sender {
    if (self.resultsTableView.numberOfSelectedRows > 0) {
        NSArray *results = [self.unusedResults copy];
        NSIndexSet *selectedIndexSet = self.resultsTableView.selectedRowIndexes;
        NSUInteger index = [selectedIndexSet firstIndex];
        while (index != NSNotFound) {
            if (index < results.count) {
                ResourceFileInfo *info = [results objectAtIndex:index];
                [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:info.path] error:nil];
            }
            index = [selectedIndexSet indexGreaterThanIndex:index];
        }
        
        [self.unusedResults removeObjectsAtIndexes:selectedIndexSet];
        [self.resultsTableView reloadData];
        [self updateUnusedResultsCount];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please select any table column."];
        [alert runModal];
    }
}

- (IBAction)onRemovePatternButtonClicked:(id)sender {
    if (self.patternTableView.numberOfSelectedRows > 0) {
        NSIndexSet *selectedIndexSet = self.patternTableView.selectedRowIndexes;
        NSUInteger index = [selectedIndexSet firstIndex];
        [[ResourceSettings sharedObject] removeResourcePatternAtIndex:index];
        [self.patternTableView reloadData];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please select any table column."];
        [alert runModal];
    }
}

- (IBAction)onAddPatternButtonClicked:(id)sender {
    [[ResourceSettings sharedObject] addResourcePattern:[[ResourceStringSearcher sharedObject] createEmptyResourcePattern]];
    [self.patternTableView reloadData];
}

- (void)onResultsTableViewSingleClicked {
    // Copy to pasteboard
    NSInteger index = [self.resultsTableView clickedRow];
    if (self.unusedResults.count == 0 || index >= self.unusedResults.count) {
        return;
    }
    ResourceFileInfo *info = [self.unusedResults objectAtIndex:index];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:info.name forType:NSStringPboardType];
}

- (void)onResultsTableViewDoubleClicked {
    // Open finder
    NSInteger index = [self.resultsTableView clickedRow];
    if (self.unusedResults.count == 0 || index >= self.unusedResults.count) {
        return;
    }
    ResourceFileInfo *info = [self.unusedResults objectAtIndex:index];
    [[NSWorkspace sharedWorkspace] selectFile:info.path inFileViewerRootedAtPath:@""];
}

- (IBAction)onIgnoreSimilarCheckboxClicked:(NSButton *)sender {
    [ResourceSettings sharedObject].matchSimilarName = sender.state == NSOnState ? @(YES) : @(NO);
}

#pragma mark - NSNotification

- (void)onResourceFileQueryDone:(NSNotification *)notification {
    self.isFileDone = YES;
    [self searchUnusedResourcesIfNeeded];
}

- (void)onResourceStringQueryDone:(NSNotification *)notification {
    self.isStringDone = YES;
    [self searchUnusedResourcesIfNeeded];
}

#pragma mark - <NSTableViewDataSource>

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.resultsTableView) {
        return self.unusedResults.count;
    } else {
        return [self resourcePatterns].count;
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Check the column
    NSString *identifier = [tableColumn identifier];
    if (tableView == self.resultsTableView) {
        // Get the unused image
        ResourceFileInfo *info = [self.unusedResults objectAtIndex:row];
        
        if ([identifier isEqualToString:kResultIdentifyFileIcon]) {
            return [info image];
        } else if ([identifier isEqualToString:kResultIdentifyFileName]) {
            return info.name;
        } else if ([identifier isEqualToString:kResultIdentifyFileSize]) {
            return [NSString stringWithFormat:@"%.2f", info.fileSize / 1024.0];
        }
        
        return info.path;
    } else {
        NSDictionary *dict = [[self resourcePatterns] objectAtIndex:row];
        return dict[identifier];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.patternTableView) {
        NSString *identifier = [tableColumn identifier];
        [[ResourceSettings sharedObject] updateResourcePatternAtIndex:row withObject:object forKey:identifier];
        
        [tableView reloadData];
    }
}

#pragma mark - <NSTableViewDelegate>

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
    if (tableView == self.patternTableView) {
        return;
    }
    NSArray *array = nil;
    if ([tableColumn.identifier isEqualToString:kResultIdentifyFileSize]) {
        self.isSortDescByFileSize = !self.isSortDescByFileSize;
        
        if (self.isSortDescByFileSize) {
            array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(ResourceFileInfo *obj1, ResourceFileInfo *obj2) {
                return obj1.fileSize < obj2.fileSize;
            }];
        } else {
            array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(ResourceFileInfo *obj1, ResourceFileInfo *obj2) {
                return obj1.fileSize > obj2.fileSize;
            }];
        }
    } else if ([tableColumn.identifier isEqualToString:kResultIdentifyFileName]) {
        array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(ResourceFileInfo *obj1, ResourceFileInfo *obj2) {
            return [obj1.name compare:obj2.name];
        }];
    } else  if ([tableColumn.identifier isEqualToString:kResultIdentifyFilePath]){
        array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(ResourceFileInfo *obj1, ResourceFileInfo *obj2) {
            return [obj1.path compare:obj2.path];
        }];
    }
    
    if (array) {
        self.unusedResults = [array mutableCopy];
        [self.resultsTableView reloadData];
    }
}

#pragma mark - <NSTextFieldDelegate>

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    if (textField == self.pathTextField) {
        [ResourceSettings sharedObject].projectPath = [textField stringValue];
    } else if (textField == self.excludeFolderTextField) {
        [ResourceSettings sharedObject].excludeFolders = [[textField stringValue] componentsSeparatedByString:kDefaultResourceSeparator];
    } else if (textField == self.resSuffixTextField) {
        NSString *suffixs = [[textField stringValue] lowercaseString];
        suffixs = [suffixs stringByReplacingOccurrencesOfString:@" " withString:@""];
        suffixs = [suffixs stringByReplacingOccurrencesOfString:@"." withString:@""];
        [ResourceSettings sharedObject].resourceSuffixs = [suffixs componentsSeparatedByString:kDefaultResourceSeparator];
    }
}

#pragma mark - Private

- (void)showAlertWithStyle:(NSAlertStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = style;
    [alert setMessageText:title];
    [alert setInformativeText:subtitle];
    [alert runModal];
}

- (NSArray *)resourceSuffixs {
    return [ResourceSettings sharedObject].resourceSuffixs;
}

- (NSArray *)resourcePatterns {
    return [ResourceSettings sharedObject].resourcePatterns;
}

- (void)setUIEnabled:(BOOL)state {
    if (state) {
        [self updateUnusedResultsCount];
    } else {
        [self.processIndicator startAnimation:self];
        self.statusLabel.stringValue = @"Searching...";
    }
    
    [_browseButton setEnabled:state];
    [_resSuffixTextField setEnabled:state];
    [_pathTextField setEnabled:state];
    [_excludeFolderTextField setEnabled:state];
    
    [_ignoreSimilarCheckbox setEnabled:state];

    [_searchButton setEnabled:state];
    [_exportButton setHidden:!state];
    [_deleteButton setEnabled:state];
    [_deleteButton setHidden:!state];
    [_processIndicator setHidden:state];
}

- (void)updateUnusedResultsCount {
    [self.processIndicator stopAnimation:self];
    NSUInteger count = self.unusedResults.count;
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.startTime];
    NSUInteger totalSize = 0;
    for(ResourceFileInfo *info in self.unusedResults){
        totalSize += info.fileSize;
    }
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Total: %ld, unsued: %ld, time: %.2fs, size: %.2f KB", [[ResourceFileSearcher sharedObject].resNameInfoDict allKeys].count, (long)count, time, (long)totalSize / 1024.0];
}

- (void)searchUnusedResourcesIfNeeded {
    NSString *tips = @"Searching...";
    if (self.isFileDone) {
        tips = [tips stringByAppendingString:[NSString stringWithFormat:@"%ld resources", [[ResourceFileSearcher sharedObject].resNameInfoDict allKeys].count]];
    }
    if (self.isStringDone) {
        tips = [tips stringByAppendingString:[NSString stringWithFormat:@"%ld strings", [ResourceStringSearcher sharedObject].resStringSet.count]];
    }
    self.statusLabel.stringValue = tips;
    
    if (self.isFileDone && self.isStringDone) {
        NSArray *resNames = [[[ResourceFileSearcher sharedObject].resNameInfoDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        for (NSString *name in resNames) {
            if (![[ResourceStringSearcher sharedObject] containsResourceName:name]) {
                if (!self.ignoreSimilarCheckbox.state
                    || ![[ResourceStringSearcher sharedObject] containsSimilarResourceName:name]) {
                    //TODO: if imageset name is A but contains png with name B, and using as B, should ignore A.imageset
                    
                    ResourceFileInfo *resInfo = [ResourceFileSearcher sharedObject].resNameInfoDict[name];
                    if (!resInfo.isDir
                        || ![self usingResWithDiffrentDirName:resInfo]) {
                        [self.unusedResults addObject:resInfo];
                    }
                }
            }
        }
        
        [self.resultsTableView reloadData];
        
        [self setUIEnabled:YES];
    }
}

- (BOOL)usingResWithDiffrentDirName:(ResourceFileInfo *)resInfo {
    if (!resInfo.isDir) {
        return NO;
    }
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:resInfo.path];
    for (NSString *fileName in fileEnumerator) {
        if (![StringUtils isImageTypeWithName:fileName]) {
            continue;
        }
        
        NSString *fileNameWithoutExt = [StringUtils stringByRemoveResourceSuffix:fileName];
        
        if ([fileNameWithoutExt isEqualToString:resInfo.name]) {
            return NO;
        }
        
        if ([[ResourceStringSearcher sharedObject] containsResourceName:fileNameWithoutExt]) {
            return YES;
        }
    }
    return NO;
}

- (void)setupSettings {
    self.unusedResults = [NSMutableArray array];
    
    [self.pathTextField setStringValue:[ResourceSettings sharedObject].projectPath ? : @""];
    NSString *exclude = @"";
    if ([ResourceSettings sharedObject].excludeFolders.count) {
        exclude = [[ResourceSettings sharedObject].excludeFolders componentsJoinedByString:kDefaultResourceSeparator];
    }
    [self.excludeFolderTextField setStringValue:exclude];
    
    NSArray *resSuffixs = [ResourceSettings sharedObject].resourceSuffixs;
    if (!resSuffixs.count) {
        resSuffixs = [kDefaultResourceSuffixs componentsSeparatedByString:kDefaultResourceSeparator];
        [ResourceSettings sharedObject].resourceSuffixs = resSuffixs;
    }
    [self.resSuffixTextField setStringValue:[resSuffixs componentsJoinedByString:kDefaultResourceSeparator]];
    
    NSArray *resPatterns = [self resourcePatterns];
//    if (!resPatterns.count) {
        resPatterns = [[ResourceStringSearcher sharedObject] createDefaultResourcePatternsWithResourceSuffixs:resSuffixs];
        [ResourceSettings sharedObject].resourcePatterns = resPatterns;
//    }
    
    NSNumber *matchSimilar = [ResourceSettings sharedObject].matchSimilarName;
    [self.ignoreSimilarCheckbox setState:matchSimilar.boolValue ? NSOnState : NSOffState];
}

@end

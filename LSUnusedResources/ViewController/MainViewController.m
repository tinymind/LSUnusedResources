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

// Constant strings
static NSString * const kDefaultResourceSuffixs    = @"imageset;jpg;gif;png";
static NSString * const kTableColumnImageIcon      = @"ImageIcon";
static NSString * const kTableColumnImageShortName = @"ImageShortName";

@interface MainViewController () <NSTableViewDelegate, NSTableViewDataSource>

// Project
@property (weak) IBOutlet NSButton *browseButton;
@property (weak) IBOutlet NSTextField *pathTextField;

// Settings
@property (weak) IBOutlet NSTextField *resSuffixTextField;

@property (weak) IBOutlet NSButton *headerCheckbox;
@property (weak) IBOutlet NSButton *mCheckbox;
@property (weak) IBOutlet NSButton *mmCheckbox;
@property (weak) IBOutlet NSButton *cppCheckbox;
@property (weak) IBOutlet NSButton *swiftCheckbox;

@property (weak) IBOutlet NSButton *htmlCheckbox;
@property (weak) IBOutlet NSButton *cssCheckbox;
@property (weak) IBOutlet NSButton *plistCheckbox;
@property (weak) IBOutlet NSButton *xibCheckbox;
@property (weak) IBOutlet NSButton *sbCheckbox;

@property (weak) IBOutlet NSButton *ignoreSimilarCheckbox;

// Result
@property (weak) IBOutlet NSTableView *resultsTableView;
@property (weak) IBOutlet NSProgressIndicator *processIndicator;
@property (weak) IBOutlet NSTextField *statusLabel;

@property (weak) IBOutlet NSButton *searchButton;
@property (weak) IBOutlet NSButton *exportButton;

@property (strong, nonatomic) NSMutableArray *unusedResults;
@property (assign, nonatomic) BOOL isFileDone;
@property (assign, nonatomic) BOOL isStringDone;

- (IBAction)onBrowseButtonClicked:(id)sender;
- (IBAction)onSearchButtonClicked:(id)sender;
- (IBAction)onExportButtonClicked:(id)sender;

@end

@implementation MainViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    // Setup double click
    self.unusedResults = [NSMutableArray array];
    [self.resultsTableView setDoubleAction:@selector(tableViewDoubleClicked)];
    
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
        NSString *path = [[openPanel directoryURL] path];
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
    
    // Reset
    [[ResourceFileSearcher sharedObject] reset];
    [[ResourceStringSearcher sharedObject] reset];
    
    [self.unusedResults removeAllObjects];
    [self.resultsTableView reloadData];
    [self setUIEnabled:NO];
    self.isFileDone = NO;
    self.isStringDone = NO;
    
    NSArray *resourceSuffixs = [self resourceSuffixs];
    if (!self.resourceSuffixs.count) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"Suffix Error" subtitle:@"Resource suffix is invalid"];
        return ;
    }
    NSArray *fileSuffixs = [self includeFileSuffixs];
    [[ResourceFileSearcher sharedObject] startWithProjectPath:projectPath resourceSuffixs:resourceSuffixs];
    [[ResourceStringSearcher sharedObject] startWithProjectPath:projectPath fileSuffixs:fileSuffixs];
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

#pragma mark - NSNotification

- (void)onResourceFileQueryDone:(NSNotification *)notification {
    self.isFileDone = YES;
    [self searchUnusedResources];
}

- (void)onResourceStringQueryDone:(NSNotification *)notification {
    self.isStringDone = YES;
    [self searchUnusedResources];
}


#pragma mark - <NSTableViewDelegate>
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.unusedResults count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    // Get the unused image
    ResourceFileInfo *info = [self.unusedResults objectAtIndex:rowIndex];
    
    // Check the column
    NSString *columnIdentifier = [tableColumn identifier];
    if ([columnIdentifier isEqualToString:kTableColumnImageIcon]) {
        return [info image];
    } else if ([columnIdentifier isEqualToString:kTableColumnImageShortName]) {
        return info.name;
    }
    
    return info.path;
}

- (void)tableViewDoubleClicked {
    // Open finder
    ResourceFileInfo *info = [self.unusedResults objectAtIndex:[self.resultsTableView clickedRow]];
    [[NSWorkspace sharedWorkspace] selectFile:info.path inFileViewerRootedAtPath:nil];
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
    NSString *suffixs = self.resSuffixTextField.stringValue;
    if (!suffixs.length) {
        suffixs = kDefaultResourceSuffixs;
    }
    suffixs = [suffixs lowercaseString];
    suffixs = [suffixs stringByReplacingOccurrencesOfString:@" " withString:@""];
    suffixs = [suffixs stringByReplacingOccurrencesOfString:@"." withString:@""];
    return [suffixs componentsSeparatedByString:@";"];
}

- (NSArray *)includeFileSuffixs {
    NSMutableArray *suffixs = [NSMutableArray array];
    
    if ([self.headerCheckbox state]) {
        [suffixs addObject:@"h"];
    }
    if ([self.mCheckbox state]) {
        [suffixs addObject:@"m"];
    }
    if ([self.mmCheckbox state]) {
        [suffixs addObject:@"mm"];
    }
    if ([self.cppCheckbox state]) {
        [suffixs addObject:@"cpp"];
    }
    if ([self.swiftCheckbox state]) {
        [suffixs addObject:@"swift"];
    }
    
    if ([self.htmlCheckbox state]) {
        [suffixs addObject:@"html"];
    }
    if ([self.plistCheckbox state]) {
        [suffixs addObject:@"plist"];
    }
    if ([self.cssCheckbox state]) {
        [suffixs addObject:@"plist"];
    }
    if ([self.xibCheckbox state]) {
        [suffixs addObject:@"xib"];
    }
    if ([self.sbCheckbox state]) {
        [suffixs addObject:@"storyboard"];
    }
    
    if (suffixs.count == 0) {
        [suffixs addObject:@"m"];
    }
    return suffixs;
}

- (void)setUIEnabled:(BOOL)state {
    // Individual
    if (state) {
        [self.processIndicator stopAnimation:self];
        NSUInteger count = self.unusedResults.count;
        NSString *tips = count > 2 ? @"resources" : @"resource";
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%d unsued %@.", (int)count, tips];
    } else {
        [self.processIndicator startAnimation:self];
        self.statusLabel.stringValue = @"Searching...";
    }
    
    // Button groups
    
    [_browseButton setEnabled:state];
    [_resSuffixTextField setEnabled:state];
    [_pathTextField setEnabled:state];
    
    [_mCheckbox setEnabled:state];
    [_xibCheckbox setEnabled:state];
    [_sbCheckbox setEnabled:state];
    [_cppCheckbox setEnabled:state];
    [_mmCheckbox setEnabled:state];
    [_headerCheckbox setEnabled:state];
    [_htmlCheckbox setEnabled:state];
    [_plistCheckbox setEnabled:state];
    [_cssCheckbox setEnabled:state];
    [_swiftCheckbox setEnabled:state];
    
    [_ignoreSimilarCheckbox setEnabled:state];

    [_searchButton setEnabled:state];
    [_exportButton setHidden:!state];
    [_processIndicator setHidden:state];
}

- (void)searchUnusedResources {
    if (self.isFileDone && self.isStringDone) {
        NSArray *resNames = [[[ResourceFileSearcher sharedObject].resNameInfoDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        for (NSString *name in resNames) {
            if (![[ResourceStringSearcher sharedObject] containsResourceName:name]) {
                if (!self.ignoreSimilarCheckbox.state
                    || ![[ResourceStringSearcher sharedObject] containsSimilarResourceName:name]) {
                    [self.unusedResults addObject:[ResourceFileSearcher sharedObject].resNameInfoDict[name]];
                }
            }
        }
        
        [self.resultsTableView reloadData];
        
        [self setUIEnabled:YES];
    }
}

@end

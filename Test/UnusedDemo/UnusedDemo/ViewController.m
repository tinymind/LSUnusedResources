//
//  ViewController.m
//  UnusedDemo
//
//  Created by lslin on 16/11/16.
//  Copyright © 2016年 lessfun.com. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Using with imageset name
    UIImage *image1 = [UIImage imageNamed:@"avatar"];
    image1 = [UIImage imageNamed:@"back"];
    image1 = [UIImage imageNamed:@"book"];
    
    // Using with PNG name
    UIImage *image2 = [UIImage imageNamed:@"dislike"];
    image2 = [UIImage imageNamed:@"download"];
    [self updateButtonWithNormalImage:@"" selectImage:@"garbage"];
    
    // Using with similar PNG name
    UIImage *image3 = [UIImage imageNamed:@"folder"];
    image3 = [UIImage imageNamed:[NSString stringWithFormat:@"folder_%d", 1]];
    image3 = [UIImage imageNamed:@"icon_apple"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)updateButtonWithNormalImage:(NSString *)normalImage selectImage:(NSString *)selectImage {
    
}

@end

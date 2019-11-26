//
//  WeexPluginVSliderModule.m
//  WeexPluginTemp
//
//  Created by  on 17/3/14.
//  Copyright © 2017年 . All rights reserved.
//

#import "WeexPluginVSliderModule.h"
#import <WeexPluginLoader/WeexPluginLoader.h>

@implementation WeexPluginVSliderModule

WX_PlUGIN_EXPORT_MODULE(weexPluginVSlider, WeexPluginVSliderModule)
WX_EXPORT_METHOD(@selector(show))

/**
 create actionsheet
 
 @param options items
 @param callback
 */
-(void)show
{
    UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"title" message:@"module weexPluginVSlider is created sucessfully" delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:@"ok", nil];
    [alertview show];
    
}

@end

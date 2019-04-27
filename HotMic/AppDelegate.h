//
//  AppDelegate.h
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "THMPlayThruController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property THMPlayThruController *playThroughController;

- (void)settingsChanged:(NSNotification *)notification;
- (void)showFatalError:(NSString *)error;

@end


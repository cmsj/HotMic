//
//  AppDelegate.m
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSError *error;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults objectForKey:@"settings"];

    self.playThroughController = [NSKeyedUnarchiver unarchivedObjectOfClass:[THMPlayThruController class]
                                                                   fromData:data
                                                                      error:&error];

    if (!self.playThroughController) {
        // We've started up with no pre-saved settings. Create a default controller, configure it and save our settings
        NSLog(@"Failed to unarchive THMPlayThruController: %@. Proceeding with no configuration", error.localizedDescription);
        self.playThroughController = [[THMPlayThruController alloc] init];
        self.playThroughController.startupDone = YES;

        // Force settings to be saved
        [self settingsChanged:[NSNotification notificationWithName:@"THMNULL" object:nil]];
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(settingsChanged:) name:@"THMSettingsChanged" object:nil];
    [center addObserver:self selector:@selector(showFatalError:) name:@"THMFatalError" object: nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
     [self.playThroughController stop];
}

- (void)settingsChanged:(NSNotification *)notification {
    NSError *error;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *settings = [NSKeyedArchiver archivedDataWithRootObject:self.playThroughController requiringSecureCoding:YES error:&error];

    if (!settings) {
        [self showFatalError:error.localizedDescription];
        return;
    }

    [defaults setObject:settings forKey:@"settings"];
    if ([defaults synchronize]) {
        NSLog(@"Settings saved");
    } else {
        [self showFatalError:@"Unable to save settings"];
    }
}

-(void)showFatalError:(NSString*)error 
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.informativeText = error;
    [alert addButtonWithTitle:@"Quit"];
    [alert runModal];
    abort();
}

@end

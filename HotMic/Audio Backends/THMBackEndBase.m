//
//  THMBackEndBase.m
//  HotMic
//
//  Created by Chris Jones on 27/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMBackEndBase.h"

@implementation THMBackEndBase

- (id)initWithInputDevice:(THMAudioDevice *)input andOutputDevice:(THMAudioDevice *)output {
    self = [super init];
    if (self) {
        isUIVisible = NO;
        inputDevice = input;
        outputDevice = output;

        // We store these explicitly to avoid a dot-property lookups in latency-sensitive audio callbacks
        inputDeviceID = input.ID;
        outputDeviceID = output.ID;

        pollForAmplitude = NO;
    }
    return self;
}

- (BOOL)start {
    // Base class can never start
    return NO;
}

- (BOOL)stop {
    // Base class can never stop
    return NO;
}

- (BOOL)isRunning {
    // Base class can never run
    return NO;
}

- (void)addUIObservers:(BOOL)withAmplitudePolling {
    __weak THMBackEndBase *weakself = self;

    pollForAmplitude = withAmplitudePolling;

    uiDidAppearObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"THMUIDidAppear" object:nil queue:nil usingBlock:^(NSNotification *notification) {
        THMBackEndBase *playThru = weakself;
        if (playThru) {
            playThru->isUIVisible = YES;

            if (playThru->pollForAmplitude) {
                NSLog(@"Starting amplitude polling timer");
                playThru->amplitudePollingTimer = [NSTimer scheduledTimerWithTimeInterval:1/30
                                                                                  repeats:YES
                                                                                    block:^(NSTimer * _Nonnull timer) {
                                                                                        [playThru updateAmplitude];
                                                                                    }];
            }
        }
    }];
    
    uiDidDisappearObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"THMUIDidDisappear" object:nil queue:nil usingBlock:^(NSNotification *notification) {
        THMBackEndBase *playThru = weakself;
        if (playThru) {
            playThru->isUIVisible = NO;
            playThru->lastAmplitude = 0.0;

            if (playThru->amplitudePollingTimer) {
                NSLog(@"Stopping amplitude polling timer");
                [playThru->amplitudePollingTimer invalidate];
                playThru->amplitudePollingTimer = nil;
            }
        }
    }];
}

- (void)removeUIObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:uiDidAppearObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:uiDidDisappearObserver];
}

- (void)updateAmplitude {
    NSLog(@"updateAmplitude called on THMBackEndBase.");
    abort();
}
@end

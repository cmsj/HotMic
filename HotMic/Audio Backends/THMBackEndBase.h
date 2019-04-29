//
//  THMBackEndBase.h
//  HotMic
//
//  Created by Chris Jones on 27/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "THMAudioDevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMBackEndBase : NSObject {
@public
    THMAudioDevice *inputDevice;
    THMAudioDevice *outputDevice;
    AudioDeviceID inputDeviceID;
    AudioDeviceID outputDeviceID;

    BOOL isUIVisible;
    Float32 lastAmplitude;

    id uiDidAppearObserver;
    id uiDidDisappearObserver;
    BOOL pollForAmplitude;
    NSTimer *amplitudePollingTimer;
}

- (id)initWithInputDevice:(THMAudioDevice *)input andOutputDevice:(THMAudioDevice *)output;
- (BOOL)start;
- (BOOL)stop;
- (BOOL)isRunning;

- (void)addUIObservers:(BOOL)withAmplitudePolling;
- (void)removeUIObservers;

- (void)updateAmplitude;
@end

NS_ASSUME_NONNULL_END

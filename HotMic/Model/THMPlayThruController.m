//
//  THMPlayThruController.m
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMPlayThruController.h"

OSStatus audiodevicewatcher_callback(AudioDeviceID deviceID, UInt32 numAddresses, const AudioObjectPropertyAddress addressList[], void *clientData) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:@"THMControllerAudioDevicesChanged" object:nil];
    });
    return noErr;
}

@implementation THMPlayThruController

#pragma mark - Instance lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.deviceList = [[THMAudioDeviceList alloc] init];
        self.inputDevice = nil;
        self.outputDevice = nil;

        _inputUID = @"__THM__DEFAULT_DEVICE__";
        _outputUID = @"__THM__DEFAULT_DEVICE__";
        _isEnabled = NO;
        self.startupDone = NO; // NOTE: This needs to come after the three ivars are set, because it triggers a setter method that needs them
        
        __weak id weakSelf = self;
        listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[]) {
            [weakSelf restart];
        };

        // Set up an observer for the THMControllerAudioDevicesChanged event, which means audio devices appeared/disappeared, or the defaults changed or something.
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(watcherCallback:) name:@"THMControllerAudioDevicesChanged" object:nil];
        [center addObserver:self selector:@selector(inputDeviceSelected:) name:@"THMViewInputDeviceSelected" object:nil];
        [center addObserver:self selector:@selector(outputDeviceSelected:) name:@"THMViewOutputDeviceSelected" object:nil];
        [center addObserver:self selector:@selector(enabledSelected:) name:@"THMViewEnabledSelected" object:nil];
        [center addObserver:self selector:@selector(pushUIState) name:@"THMViewDidLoad" object:nil];

        self.startupDone = YES;
    }
    return self;
}

- (void)dealloc {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:@"THMControllerAudioDevicesChanged" object:nil];

    [self stop];
}

#pragma mark - NSCoding protocol
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];
    if (self) {
        _isEnabled = [aDecoder decodeBoolForKey:@"isEnabled"];
        _inputUID = [aDecoder decodeObjectOfClass:NSString.class forKey:@"inputUID"];
        _outputUID = [aDecoder decodeObjectOfClass:NSString.class forKey:@"outputUID"];
        [self validateAndRestart];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    //NSLog(@"encodeWithCoder: %@, %@, %@", self.isEnabled ? @"YES" : @"NO", self.inputUID, self.outputUID);
    [aCoder encodeBool:self.isEnabled forKey:@"isEnabled"];
    [aCoder encodeObject:self.inputUID forKey:@"inputUID"];
    [aCoder encodeObject:self.outputUID forKey:@"outputUID"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - Private setters
- (void)setInputUID:(NSString *)inputUID {
    THMAudioDevice *device = [self.deviceList audioDeviceForUID:inputUID input:YES];
    self.inputDevice = nil;

    if (device) {
        _inputUID = inputUID;
        self.inputDevice = device;
        NSLog(@"Set input device to: %d:%@", self.inputDevice.ID, self.inputDevice.name);
        self.inputDevice.format.Print();
    } else {
        NSLog(@"ERROR: Unable to find device with UID: %@", inputUID);
    }

    return;
}

- (void)setOutputUID:(NSString *)outputUID {
    THMAudioDevice *device = [self.deviceList audioDeviceForUID:outputUID input:NO];
    self.outputDevice = nil;

    if (device) {
        _outputUID = outputUID;
        self.outputDevice = device;
        NSLog(@"Set output device to: %d:%@", self.outputDevice.ID, self.outputDevice.name);
        self.outputDevice.format.Print();
    } else {
        NSLog(@"ERROR: Unable to find device with UID: %@", outputUID);
    }

    return;
}

- (void)setIsEnabled:(BOOL)isEnabled {
    _isEnabled = isEnabled;
}

- (void)setStartupDone:(BOOL)startupDone {
    _startupDone = startupDone;
    [self pushUIState];
}

#pragma mark - Controller lifecycle
- (BOOL)canStart {
    NSString *reason;
    BOOL result = NO;

    if (!self.startupDone) {
        reason = @"Startup not finished";
    } else if (!self.isEnabled) {
        reason = @"UI state disabled";
    } else if (!self.inputDevice) {
        reason = @"No valid input device";
    } else if (!self.outputDevice) {
        reason = @"No valid output device";
    } else if (self.running) {
        reason = @"Already running";
    } else {
        reason = @"YES";
        result = YES;
    }

    // If we don't have valid input devices, we should disable ourselves
    if (self.isEnabled && (!self.inputDevice || !self.outputDevice)) {
        self.isEnabled = NO;
        [self pushUIState];
    }

    NSLog(@"canStart: %@", reason);
    return result;
}

- (BOOL)isRunning {
    return self.playThru && self.playThru.isRunning;
}

- (void)start {
    if (!self.canStart) {
        // No need to output anything here, canStart will log the reason
        return;
    }

    //self.playThru = (THMBackEndBase *)[[THMBackEndCAPlayThrough alloc] initWithInputDevice:self.inputDevice andOutputDevice:self.outputDevice];
    self.playThru = (THMBackEndBase *)[[THMBackEndAVFCapture alloc] initWithInputDevice:self.inputDevice andOutputDevice:self.outputDevice];
    [THMSingleton sharedInstance].playThru = self.playThru;

    streamListenerQueue = dispatch_queue_create("net.tenshu.HotMic.streamListenerQueue", DISPATCH_QUEUE_SERIAL);
    [self.inputDevice addStreamListeners:listenerBlock withQueue:streamListenerQueue];
    [self.playThru start];
    NSLog(@"playThru isRunning: %@", [self.playThru isRunning] ? @"YES" : @"NO");

    [self startWatcher];
}

- (void)stop {
    if (!self.running) {
        return;
    }
    [self stopWatcher];

    [self.playThru stop];
    [self.inputDevice removeStreamListeners:listenerBlock withQueue:streamListenerQueue];
    streamListenerQueue = nil;
    self.playThru = nil;
    [THMSingleton sharedInstance].playThru = nil;
}

- (void)restart {
    [self stop];
    [self start];
}

- (BOOL)validateAndRestart {
    [self stop];

    [self setInputUID:self.inputUID];
    [self setOutputUID:self.outputUID];

    [self start];

    [self pushUIState];
    return YES;
}

- (void)pushUIState {
    NSDictionary *state = @{@"startupDone": [NSNumber numberWithBool:self.startupDone],
                            @"isEnabled": [NSNumber numberWithBool:self.isEnabled],
                            @"inputDeviceUID": self.inputUID,
                            @"outputDeviceUID": self.outputUID,
                            @"inputVolume": [NSNumber numberWithFloat:self.inputDevice.volume],
                            @"outputVolume": [NSNumber numberWithFloat:self.outputDevice.volume]
                            };

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"THMControllerPushUIState" object:nil userInfo:state];
}

#pragma mark - Audio Device watcher lifecycle

- (void)startWatcher {
    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectAddPropertyListener(kAudioObjectSystemObject, &propertyAddress, audiodevicewatcher_callback, nil);
    }
}

- (void)stopWatcher {
    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &propertyAddress, &audiodevicewatcher_callback, nil);
    }
}

#pragma mark - NSNotification callbacks

- (void)watcherCallback:(NSNotification*)notification {
    NSLog(@"Audio devices changed, re-validating selected devices and restarting play-through");
    if (![self validateAndRestart]) {
        // Currently selected audio devices are invalid
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        // FIXME: We should indicate whether it was input or output that was invalid
        [center postNotificationName:@"THMAudioDevicesInvalid" object:nil];
    }
}

- (void)inputDeviceSelected:(NSNotification *)notification {
    self.inputUID = notification.userInfo[@"uuid"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"THMSettingsChanged" object:nil];
    NSLog(@"User selected input device: %@", self.inputUID);
    [self validateAndRestart];
}

- (void)outputDeviceSelected:(NSNotification *)notification {
    self.outputUID = notification.userInfo[@"uuid"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"THMSettingsChanged" object:nil];
    NSLog(@"User selected output device: %@", self.outputUID);
    [self validateAndRestart];
}

- (void)enabledSelected:(NSNotification *)notification {
    self.isEnabled = ((NSNumber *)notification.userInfo[@"state"]).boolValue;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"THMSettingsChanged" object:nil];
    NSLog(@"User changed enabled state: %@", self.isEnabled ? @"YES" : @"NO");
    [self validateAndRestart];
}
@end

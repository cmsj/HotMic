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

    self.playThru = [[THMPlayThru alloc] initWithInputDevice:self.inputDevice andOutputDevice:self.outputDevice];
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
    [self deleteAggregateDevice];
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
                            @"outputDeviceUID": self.outputUID
                            };

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"THMControllerPushUIState" object:nil userInfo:state];
}

#pragma mark - Aggregate Device lifecycle
- (BOOL)createAggregateDevice {
    OSStatus status = noErr;
    UInt32 outSize = 0;
    Boolean outWritable;

    AudioObjectPropertyAddress propertyAddress;
    propertyAddress.mSelector = kAudioHardwarePropertyPlugInForBundleID;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = kAudioObjectPropertyElementMaster;

    status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &outSize);
    checkErrBool(status);
    status = AudioObjectIsPropertySettable(kAudioObjectSystemObject, &propertyAddress, &outWritable);
    checkErrBool(status);

    AudioValueTranslation pluginAVT;

    CFStringRef inBundleRef = CFSTR("com.apple.audio.CoreAudio");
    AudioObjectID pluginID = UINT32_MAX;

    pluginAVT.mInputData = &inBundleRef;
    pluginAVT.mInputDataSize = sizeof(inBundleRef);
    pluginAVT.mOutputData = &pluginID;
    pluginAVT.mOutputDataSize = sizeof(pluginID);

    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &outSize, &pluginAVT);
    if (status != noErr || pluginID == UINT32_MAX)
        return NO;


    CFMutableDictionaryRef aggDeviceDict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(aggDeviceDict, CFSTR(kAudioAggregateDeviceNameKey), CFSTR("HotMic"));
    CFDictionaryAddValue(aggDeviceDict, CFSTR(kAudioAggregateDeviceUIDKey), CFSTR("net.tenshu.Hotmic"));

    /* This should make the device private, but it always throws OSError 1852797029 which is some kind of illegal operation error. Yay.
     int value = 1;
     CFNumberRef cfValue = CFNumberCreate(NULL, kCFNumberIntType, &value);
     CFDictionaryAddValue(aggDeviceDict, CFSTR(kAudioAggregateDeviceIsPrivateKey), cfValue);
     */

    CFMutableArrayRef subDevicesArray = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    CFArrayAppendValue(subDevicesArray, (__bridge CFStringRef)self.inputDevice.UID);
    CFArrayAppendValue(subDevicesArray, (__bridge CFStringRef)self.outputDevice.UID);

    //-----------------------
    // Feed the dictionary to the plugin, to create a blank aggregate device
    //-----------------------

    propertyAddress.mSelector = kAudioPlugInCreateAggregateDevice;

    status = AudioObjectGetPropertyDataSize(pluginID, &propertyAddress, 0, NULL, &outSize);
    checkErrBool(status);

    AudioDeviceID outAggregateDevice;

    status = AudioObjectGetPropertyData(pluginID, &propertyAddress, sizeof(aggDeviceDict), &aggDeviceDict, &outSize, &outAggregateDevice);
    checkErrBool(status);

    // pause for a bit to make sure that everything completed correctly
    // this is to work around a bug in the HAL where a new aggregate device seems to disappear briefly after it is created
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);

    //-----------------------
    // Set the sub-device list
    //-----------------------

    propertyAddress.mSelector = kAudioAggregateDevicePropertyFullSubDeviceList;

    outSize = sizeof(CFMutableArrayRef);
    status = AudioObjectSetPropertyData(outAggregateDevice, &propertyAddress, 0, NULL, outSize, &subDevicesArray);
    checkErrBool(status);

    // pause again to give the changes time to take effect
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);

    //-----------------------
    // Set the master device
    //-----------------------

    // set the master device manually (this is the device which will act as the master clock for the aggregate device)
    // pass in the UID of the device you want to use
    propertyAddress.mSelector = kAudioAggregateDevicePropertyMasterSubDevice;
    CFStringRef deviceUID = (__bridge CFStringRef)self.outputDevice.UID;
    outSize = sizeof(deviceUID);

    status = AudioObjectSetPropertyData(outAggregateDevice, &propertyAddress, 0, NULL, outSize, &deviceUID);
    checkErrBool(status);

    // FIXME: Do we need to do anything with either kAudioAggregateDevicePropertyClockDevice or kAudioSubDevicePropertyDriftCompensation here?
    // (if so, we need to do the runloop pause before the drift compensation, it would seem: https://lists.apple.com/archives/coreaudio-api/2014/Mar/msg00037.html

    // pause again to give the changes time to take effect
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
    //-----------------------
    // Clean up
    //-----------------------

    // release the CF objects we have created - we don't need them any more
    CFRelease(aggDeviceDict);

    self.aggregate = [[THMAudioDevice alloc] initWithDeviceID:outAggregateDevice input:YES];
    NSLog(@"Created aggregate device: %@ (%u)", self.aggregate.UID, (unsigned int)self.aggregate.ID);

    return YES;
}

// FIXME: This never seems to work for me, even though it looks correct to my eyes. Consistently throws an OSError 2003332927 at the GetPropertyDataSize
- (BOOL)deleteAggregateDevice {
    AudioObjectPropertyAddress property_address;
    property_address.mSelector = kAudioPlugInDestroyAggregateDevice;
    property_address.mScope = kAudioObjectPropertyScopeGlobal;
    property_address.mElement = kAudioObjectPropertyElementMaster;
    UInt32 outDataSize = 0;

    AudioDeviceID deviceID = self.aggregate.ID;

    NSLog(@"Attempting to destroy aggregate device: %@ (%u)", self.aggregate.UID, (unsigned int)deviceID
          );

    checkErrBool(AudioObjectGetPropertyDataSize(deviceID, &property_address, 0, NULL, &outDataSize));

    checkErrBool(AudioObjectGetPropertyData(deviceID, &property_address, 0, NULL, &outDataSize, &deviceID));

    self.aggregate = nil;

    return YES;
}

- (BOOL)aggregateDeviceExists {
    return NO;
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

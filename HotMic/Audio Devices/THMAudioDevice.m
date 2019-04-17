//
//  THMAudioDevice.m
//  HotMic
//
//  Created by Chris Jones on 29/03/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMAudioDevice.h"

@implementation THMAudioDevice
- (id)initWithDeviceID:(UInt32)deviceID input:(BOOL)input {
    if (deviceID == kAudioDeviceUnknown) {
        return nil;
    }

    self = [super init];
    if (self) {
        self.ID = deviceID;
        scope = input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;

        __weak THMAudioDevice *weakself = self;
        volumeChangedBlock = ^(UInt32 numAddresses, const AudioObjectPropertyAddress *inAddresses) {
            for (UInt32 addressIndex = 0; addressIndex < numAddresses; addressIndex++) {
                AudioObjectPropertyAddress currentAddress = inAddresses[addressIndex];

                switch (currentAddress.mSelector) {
                    case kAudioDevicePropertyVolumeScalar:
                        Float32 volume = 0.0;
                        UInt32 dataSize = sizeof(volume);
                        OSStatus result = AudioObjectGetPropertyData(deviceID, &currentAddress, 0, NULL, &dataSize, &volume);
                        if (result == noErr) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [weakself setSliderValue:(float)volume];
                            });
                        }
                        break;
                }
            }
        };
    }

    return self;
}

- (BOOL)isValid {
    return self.ID != kAudioDeviceUnknown;
}

- (NSString *)getName {
    CFStringRef name = NULL;
    NSString *theName = @"Unknown";
    UInt32 propsize = sizeof(name);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyData(self.ID, &propertyAddress, 0, NULL, &propsize, &name) == noErr) {
        theName = [(__bridge NSString *)name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return theName;
}

- (NSString *)getUID {
    CFStringRef uid = NULL;
    NSString *theUID = @"Unknown";
    UInt32 propsize = sizeof(uid);

    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyDeviceUID,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propsize, &uid) == noErr) {
        theUID = (__bridge NSString *)uid;
    }

    return theUID;
}

- (NSArray *)getSourcesByScope:(AudioObjectPropertyScope)theScope {
    UInt32 datasourceListPropertySize = 0;
    UInt32 *datasourceList = NULL;
    UInt32 i;
    NSMutableArray *sources = [[NSMutableArray alloc] init];

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSources,
        theScope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyDataSize(self.ID, &propertyAddress, 0, NULL, &datasourceListPropertySize) != noErr)
        return @[];

    datasourceList = (UInt32 *)calloc(datasourceListPropertySize, sizeof(UInt32));

    if (AudioObjectGetPropertyData(self.ID, &propertyAddress, 0, NULL, &datasourceListPropertySize, datasourceList) != noErr) {
        free(datasourceList);
        return @[];
    }

    for(i = 0; i < datasourceListPropertySize; i++) {
        if (datasourceList[i] == 0) {
            continue;
        }
        THMAudioDeviceSource *source = [[THMAudioDeviceSource alloc] initWithSourceID:datasourceList[i]
                                                                          andDeviceID:self.ID
                                                                                input:(scope == kAudioObjectPropertyScopeInput ? YES : NO)];
        [sources addObject:source];
    }

    free(datasourceList);
    return [sources copy];
}

- (NSArray *)getSources {
    return [self getSourcesByScope:scope];
}

- (int)getChannelCount {
    OSStatus err;
    UInt32 propSize;
    int result = 0;

    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStreamConfiguration,
        scope,
        kAudioObjectPropertyElementMaster };

    err = AudioObjectGetPropertyDataSize(self.ID, &theAddress, 0, NULL, &propSize);
    if (err) return 0;

    AudioBufferList *buflist = (AudioBufferList *)malloc(propSize);
    err = AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propSize, buflist);
    if (!err) {
        for (UInt32 i = 0; i < buflist->mNumberBuffers; ++i) {
            result += buflist->mBuffers[i].mNumberChannels;
        }
    }
    free(buflist);
    return result;
}

- (UInt32)getBufferSize {
    UInt32 size = 0;
    UInt32 propsize = sizeof(UInt32);

    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyBufferFrameSize,
        scope,
        kAudioObjectPropertyElementMaster };

    AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propsize, &size);

    return size;
}

- (void)setBufferSize:(UInt32)bufferSize {
    UInt32 propsize = sizeof(UInt32);

    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyBufferFrameSize,
        scope,
        kAudioObjectPropertyElementMaster };

    AudioObjectSetPropertyData(self.ID, &theAddress, 0, NULL, propsize, &bufferSize);
}

- (CAStreamBasicDescription)getFormat {
    CAStreamBasicDescription format;
    UInt32 propsize = sizeof(AudioStreamBasicDescription);

    AudioObjectPropertyAddress theAddress = { kAudioStreamPropertyVirtualFormat,
        scope,
        kAudioObjectPropertyElementMaster };

    AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propsize, &format);

    return format;
}

- (UInt32)getSafetyOffset {
    UInt32 propsize = sizeof(UInt32);
    UInt32 safetyOffset = 0;

    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertySafetyOffset,
        scope,
        kAudioObjectPropertyElementMaster };

    AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propsize, &safetyOffset);

    return safetyOffset;
}

- (void)addStreamListeners:(AudioObjectPropertyListenerBlock)block withQueue:(nonnull dispatch_queue_t)queue {
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyStreams,
        kAudioDevicePropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    // StreamListenerBlock is called whenever the sample rate changes (as well as other format characteristics of the device)
    UInt32 propSize;
    OSStatus err = AudioObjectGetPropertyDataSize(self.ID, &theAddress, 0, NULL, &propSize);
    if (err) {
        NSLog(@"Error %ld returned from AudioObjectGetPropertyDataSize", (long)err);
        return;
    }

    AudioStreamID *streams = (AudioStreamID*)malloc(propSize);
    err = AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propSize, streams);
    if (err) {
        NSLog(@"Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
        return;
    }

    UInt32 numStreams = propSize / sizeof(AudioStreamID);

    for(UInt32 i = 0; i < numStreams; i++) {
        UInt32 isInput;
        propSize = sizeof(UInt32);
        theAddress.mSelector = kAudioStreamPropertyDirection;
        theAddress.mScope = kAudioObjectPropertyScopeGlobal;

        err = AudioObjectGetPropertyData(streams[i], &theAddress, 0, NULL, &propSize, &isInput);
        if (err) {
            NSLog(@"Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
            continue;
        }

        if(isInput) {
            theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;

            err = AudioObjectAddPropertyListenerBlock(streams[i], &theAddress, queue, block);
            if (err) NSLog(@"Error %ld returned from AudioObjectAddPropertyListenerBlock\n", (long)err);
        }
    }

    if (streams) free(streams);
}

- (void)removeStreamListeners:(AudioObjectPropertyListenerBlock)block withQueue:(nonnull dispatch_queue_t)queue {
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyStreams,
        kAudioDevicePropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    // FIXME: REmove the fprinfs or make them NSLogs or something
    UInt32 propSize;
    OSStatus err = AudioObjectGetPropertyDataSize(self.ID, &theAddress, 0, NULL, &propSize);
    if (err) {
        fprintf(stderr, "Error %ld returned from AudioObjectGetPropertyDataSize\n", (long)err);
        return;
    }

    AudioStreamID *streams = (AudioStreamID*)malloc(propSize);
    err = AudioObjectGetPropertyData(self.ID, &theAddress, 0, NULL, &propSize, streams);
    if (err) {
        NSLog(@"Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
        return;
    }

    UInt32 numStreams = propSize / sizeof(AudioStreamID);

    for(UInt32 i = 0; i < numStreams; i++) {
        UInt32 isInput;
        propSize = sizeof(UInt32);
        theAddress.mSelector = kAudioStreamPropertyDirection;
        theAddress.mScope = kAudioObjectPropertyScopeGlobal;

        err = AudioObjectGetPropertyData(streams[i], &theAddress, 0, NULL, &propSize, &isInput);
        if (err) {
            NSLog(@"Error %ld returned from AudioObjectGetPropertyData\n", (long)err);
            continue;
        }

        if(isInput) {
            theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;

            err = AudioObjectRemovePropertyListenerBlock(streams[i], &theAddress, queue, block);
            if (err) NSLog(@"Error %ld returned from AudioObjectRemovePropertyListenerBlock\n", (long)err);
        }
    }

    if (streams) free(streams);
}

- (void)startVolumeWatcher:(NSSlider *)slider {
    OSStatus result;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        scope,
        kAudioObjectPropertyElementWildcard
    };

    AudioDeviceID deviceID = self.ID;

    result = AudioObjectAddPropertyListenerBlock(deviceID, &propertyAddress, NULL, volumeChangedBlock);
    if (result == noErr) {
        self.slider = slider;
    }
}

- (void)stopVolumeWatcher {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        scope,
        kAudioObjectPropertyElementWildcard
    };

    AudioDeviceID deviceID = self.ID;

    AudioObjectRemovePropertyListenerBlock(deviceID, &propertyAddress, NULL, volumeChangedBlock);
    self.slider = nil;
}

- (void)setSliderValue:(float)value {
    self.slider.floatValue = value;
}

- (void)setVolume:(float)value {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        scope,
        kAudioObjectPropertyElementMaster
    };

    Float32 volume = (Float32)value;
    UInt32 volumeSize = sizeof(volume);
    OSStatus result = AudioObjectSetPropertyData(self.ID, &propertyAddress, 0, NULL, volumeSize, &volume);

    if (result != noErr) {
        NSLog(@"THMAudioDevice::setVolume failed: %d", (int)result);
    }
}
@end

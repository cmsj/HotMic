//
//  THMAudioDeviceList.m
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMAudioDeviceList.h"

@implementation THMAudioDeviceList
+ (NSArray <THMAudioDevice*>*)getAudioDevices:(BOOL)input {
    NSMutableArray *audioDevices = [[NSMutableArray alloc] init];
    UInt32 i;
    AudioDeviceID *deviceList = NULL;
    UInt32 numDevices = 0;
    UInt32 deviceListPropertySize = 0;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize) != noErr)
        return @[];

    numDevices = deviceListPropertySize / sizeof(AudioDeviceID);
    deviceList = (AudioDeviceID*) calloc(numDevices, sizeof(AudioDeviceID));

    if (!deviceList)
        return @[];

    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize, deviceList) != noErr) {
        free(deviceList);
        return @[];
    }

    for (i = 0; i < numDevices; i++) {
        THMAudioDevice *audioDevice = [[THMAudioDevice alloc] initWithDeviceID:deviceList[i] input:input];
        if (audioDevice.channels > 0) {
            [audioDevices addObject:audioDevice];
            //NSLog(@"Found audio device: %d:%@::'%@'", audioDevice.ID, audioDevice.name, audioDevice.UID);
        }
    }

    free(deviceList);
    return [audioDevices copy];
}

+ (THMAudioDevice *)getDefaultDevice:(BOOL)input {
    AudioObjectPropertySelector selector;

    if (input) {
        selector = kAudioHardwarePropertyDefaultInputDevice;
    } else {
        selector = kAudioHardwarePropertyDefaultOutputDevice;
    }

    AudioObjectPropertyAddress propertyAddress = {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId) == noErr) {
        return [[THMAudioDevice alloc] initWithDeviceID:deviceId input:input];
    }

    return nil;
}

- (id)init {
    self = [super init];
    if (self) {
        [self refreshDeviceLists];
    }
    return self;
}

- (void)refreshDeviceLists {
    self.inputDevices = [THMAudioDeviceList getAudioDevices:YES];
    self.outputDevices = [THMAudioDeviceList getAudioDevices:NO];
}

- (THMAudioDevice *)audioDeviceForUID:(NSString*)uid input:(BOOL)input {
    if ([uid isEqualToString:@"__THM__DEFAULT_DEVICE__"]) {
        return [THMAudioDeviceList getDefaultDevice:input];
    }

    NSArray *array = nil;
    if (input) {
        array = self.inputDevices;
    } else {
        array = self.outputDevices;
    }

    return [[array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.UID == %@", uid]] firstObject];
}
@end

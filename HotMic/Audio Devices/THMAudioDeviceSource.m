//
//  THMAudioDeviceSource.m
//  HotMic
//
//  Created by Chris Jones on 29/03/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMAudioDeviceSource.h"

@implementation THMAudioDeviceSource

- (id)initWithSourceID:(UInt32)ID andDeviceID:(AudioDeviceID)deviceID input:(BOOL)input{
    self = [super init];
    if (self) {
        self.ID = ID;
        self.deviceID = deviceID;
        self.isInput = input;
        nameCache = nil;
    }
    return self;
}

- (NSString *)getName {
    if (!nameCache) {
        nameCache = @"Unknown";
        CFStringRef dataSourceName;

        AudioObjectPropertyScope scope = self.isInput ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput;

        AudioObjectPropertyAddress propertyAddress = {
            kAudioDevicePropertyDataSourceNameForIDCFString,
            scope,
            kAudioObjectPropertyElementMaster
        };

        AudioValueTranslation avt;
        UInt32 id = self.ID;
        avt.mInputData = (void *)&id;
        avt.mInputDataSize = sizeof(UInt32);
        avt.mOutputData = (void *)&dataSourceName;
        avt.mOutputDataSize = sizeof(CFStringRef);

        UInt32 avtSize = sizeof(avt);

        if (AudioObjectGetPropertyData(self.deviceID, &propertyAddress, 0, NULL, &avtSize, &avt) == noErr) {
            nameCache = (__bridge_transfer NSString *)dataSourceName;
        }
    }
    return nameCache;
}

- (BOOL)setDefault {
    // FIXME: TODO
    return NO;
}
@end

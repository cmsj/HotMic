//
//  THMAudioDeviceList.h
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "THMAudioDevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMAudioDeviceList : NSObject
@property NSArray <THMAudioDevice*>* inputDevices;
@property NSArray <THMAudioDevice*>* outputDevices;

+ (NSArray <THMAudioDevice*>*)getAudioDevices:(BOOL)input;
+ (THMAudioDevice *)getDefaultDevice:(BOOL)input;

- (void)refreshDeviceLists;
- (THMAudioDevice *)audioDeviceForUID:(NSString*)uid input:(BOOL)input;
@end

NS_ASSUME_NONNULL_END

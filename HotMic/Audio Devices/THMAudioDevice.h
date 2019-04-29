//
//  THMAudioDevice.h
//  HotMic
//
//  Created by Chris Jones on 29/03/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <Dispatch/Dispatch.h>

#import "THMAudioDeviceSource.h"
#import "CAStreamBasicDescription.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMAudioDevice : NSObject {
    AudioObjectPropertyScope scope;
    AudioObjectPropertyListenerBlock volumeChangedBlock;
}
@property UInt32 ID;
@property (readonly, getter=isValid) BOOL valid;
@property (readonly, getter=getName) NSString *name;
@property (readonly, getter=getUID) NSString *UID;
@property (readonly, getter=getSources) NSArray *sources;
@property (readonly, getter=getChannelCount) int channels;
@property (getter=getBufferSize, setter=setBufferSize:) UInt32 bufferSize;
@property (readonly, getter=getFormat) CAStreamBasicDescription format;
@property (readonly, getter=getSafetyOffset) UInt32 safetyOffset;
@property (nonatomic) NSSlider * _Nullable slider;
@property (nonatomic, getter=getVolume, setter=setVolume:) float volume;

- (id)initWithDeviceID:(UInt32)deviceID input:(BOOL)input;
- (void)addStreamListeners:(AudioObjectPropertyListenerBlock)block withQueue:(dispatch_queue_t)queue;
- (void)removeStreamListeners:(AudioObjectPropertyListenerBlock)block withQueue:(dispatch_queue_t)queue;

- (void)startVolumeWatcher:(NSSlider *)slider;
- (void)stopVolumeWatcher;
- (void)setSliderValue:(float)value;
- (void)setVolume:(float)value;
- (float)getVolume;

- (BOOL)isValid;
- (NSString *)getName;
- (NSString *)getUID;
- (NSArray *)getSourcesByScope:(AudioObjectPropertyScope)scope;
- (NSArray *)getSources;
- (int)getChannelCount;
- (void)setBufferSize:(UInt32)bufferSize;
- (UInt32)getBufferSize;
- (CAStreamBasicDescription)getFormat;
- (UInt32)getSafetyOffset;

@end

NS_ASSUME_NONNULL_END

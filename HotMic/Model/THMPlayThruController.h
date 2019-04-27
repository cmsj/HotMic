//
//  THMPlayThruController.h
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "THMAudioDeviceList.h"
#import "THMAudioDevice.h"
#import "THMAudioDeviceSource.h"
#import "THMBackEndCAPlayThrough.h"
#import "THMBackEndAVFCapture.h"
#import "THMSingleton.h"

const AudioObjectPropertySelector watchSelectors[] = {
    kAudioHardwarePropertyDevices,
    kAudioHardwarePropertyDefaultInputDevice,
    kAudioHardwarePropertyDefaultOutputDevice,
    kAudioHardwarePropertyDefaultSystemOutputDevice,
};

OSStatus audiodevicewatcher_callback(AudioDeviceID deviceID, UInt32 numAddresses, const AudioObjectPropertyAddress addressList[_Nullable], void * _Nullable clientData);

NS_ASSUME_NONNULL_BEGIN

@interface THMPlayThruController : NSObject <NSCoding, NSSecureCoding> {
    dispatch_queue_t streamListenerQueue;
    AudioObjectPropertyListenerBlock listenerBlock;
}

@property THMBackEndBase * _Nullable playThru;
@property THMAudioDeviceList *deviceList;
@property (nonatomic, setter=setInputUID:) NSString *inputUID;
@property (nonatomic, setter=setOutputUID:) NSString *outputUID;
@property (readonly, getter=isRunning) BOOL running;
@property THMAudioDevice * _Nullable inputDevice;
@property THMAudioDevice * _Nullable outputDevice;
@property (nonatomic, setter=setIsEnabled:) BOOL isEnabled;
@property (nonatomic, setter=setStartupDone:) BOOL startupDone;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (BOOL)canStart;
- (void)start;
- (void)stop;
- (void)restart;
- (BOOL)validateAndRestart;
- (BOOL)isRunning;
- (void)startWatcher;
- (void)stopWatcher;
- (void)pushUIState;
- (void)watcherCallback:(NSNotification *)notification;
- (void)inputDeviceSelected:(NSNotification *)notification;
- (void)outputDeviceSelected:(NSNotification *)notification;
- (void)enabledSelected:(NSNotification *)notification;
@end

NS_ASSUME_NONNULL_END

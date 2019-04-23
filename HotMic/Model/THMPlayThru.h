//
//  THMPlayThru.h
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "THMAudioDevice.h"

#import "CARingBuffer.h"
#import "CAStreamBasicDescription.h"

OSStatus InputProc(void * _Nonnull inRefCon,
                   AudioUnitRenderActionFlags * _Nonnull ioActionFlags,
                   const AudioTimeStamp * _Nonnull inTimeStamp,
                   UInt32 inBusNumber,
                   UInt32 inNumberFrames,
                   AudioBufferList * _Nonnull ioData);
OSStatus OutputProc(void * _Nonnull inRefCon,
                    AudioUnitRenderActionFlags * _Nonnull ioActionFlags,
                    const AudioTimeStamp * _Nonnull TimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                    AudioBufferList * _Nonnull ioData);

NS_ASSUME_NONNULL_BEGIN

@interface THMPlayThru : NSObject {
@public
    THMAudioDevice *inputDevice;
    THMAudioDevice *outputDevice;
    AudioDeviceID inputDeviceID;
    AudioDeviceID outputDeviceID;

    AudioUnit mInputUnit;
    AudioBufferList *mInputBuffer;
    CARingBuffer *mBuffer;

    AUGraph mGraph;
    AUNode mVarispeedNode;
    AudioUnit mVarispeedUnit;
    AUNode mOutputNode;
    AudioUnit mOutputUnit;

    Float64 mFirstInputTime;
    Float64 mLastInputTime;
    Float64 mFirstOutputTime;
    Float64 mInToOutSampleOffset;
    Float64 mTargetSampleDelta;

    BOOL isUIVisible;
    Float32 lastAmplitude;
}

@property (nonatomic) id uiDidAppearObserver;
@property (nonatomic) id uiDidDisappearObserver;

- (id)initWithInputDevice:(THMAudioDevice *)input andOutputDevice:(THMAudioDevice *)output;
- (BOOL)start;
- (BOOL)stop;
- (BOOL)isRunning;

- (BOOL)setInputDeviceAsCurrent;
- (BOOL)setOutputDeviceAsCurrent;
- (BOOL)setupGraph;
- (BOOL)makeGraph;
- (BOOL)setupAUHAL;
- (BOOL)enableIO;
- (BOOL)CallbackSetup;
- (BOOL)SetupBuffers;

- (void)computeThruOffset;

@end

NS_ASSUME_NONNULL_END

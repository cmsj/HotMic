//
//  THMBackEndAVFCapture.m
//  HotMic
//
//  Created by Chris Jones on 27/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMBackEndAVFCapture.h"

@implementation THMBackEndAVFCapture

- (id)initWithInputDevice:(THMAudioDevice *)input andOutputDevice:(THMAudioDevice *)output {
    self = [super initWithInputDevice:input andOutputDevice:output];
    if (self) {
        [self addUIObservers:YES];
    }
    return self;
}

- (void)dealloc {
    [self removeUIObservers];
    [self stop];
}

- (BOOL)start {
    NSError *error;

    if ([self isRunning]) {
        return YES;
    }

    audioInputDevice = [AVCaptureDevice deviceWithUniqueID:inputDevice.UID];
    if (!audioInputDevice) {
        [self cleanupAVSession];
        return NO;
    }

    audioSessionInput = [AVCaptureDeviceInput deviceInputWithDevice:audioInputDevice error:&error];
    if (error) {
        NSLog(@"Error initialising AVCaptureDeviceInput: %@", error);
        [self cleanupAVSession];
        return NO;
    }

    audioSessionOutput = [[AVCaptureAudioPreviewOutput alloc] init];
    audioSessionOutput.outputDeviceUniqueID = outputDevice.UID;
    audioSessionOutput.volume = 1.0;

    session = [[AVCaptureSession alloc] init];
    [session stopRunning];
    [session beginConfiguration];
    if ([session canAddInput:audioSessionInput]) {
        [session addInputWithNoConnections:audioSessionInput];
    } else {
        NSLog(@"Unable to add %@ as an AVCaptureSession input device", inputDevice);
        [self cleanupAVSession];
        return NO;
    }

    if ([session canAddOutput:audioSessionOutput]) {
        [session addOutputWithNoConnections:audioSessionOutput];
    } else {
        NSLog(@"Unable to add %@ as an AVCaptureSession output device", outputDevice);
        [self cleanupAVSession];
        return NO;
    }

    audioSessionConnection = [AVCaptureConnection connectionWithInputPorts:audioSessionInput.ports output:audioSessionOutput];
    if ([session canAddConnection:audioSessionConnection]) {
        [session addConnection:audioSessionConnection];
    } else {
        NSLog(@"Unable to add AVCaptureConnection between %@ and %@", inputDevice, outputDevice);
        [self cleanupAVSession];
        return NO;
    }

    [session commitConfiguration];
    [session startRunning];

    return YES;
}

- (void)updateAmplitude {
    float averagePowerDB = 0.0;

    for (AVCaptureAudioChannel *channel in audioSessionConnection.audioChannels) {
        averagePowerDB += channel.averagePowerLevel;
    }

    averagePowerDB = averagePowerDB / audioSessionConnection.audioChannels.count;
    //NSLog(@"Calculated average power for %lu channels as %f", (unsigned long)channels.count, averagePowerDB);

    lastAmplitude = (averagePowerDB + 212) / 212;
}

- (BOOL) stop {
    if (![self isRunning]) {
        return YES;
    }

    [self cleanupAVSession];
    return YES;
}

- (void)cleanupAVSession {
    if (session) {
        [session stopRunning];

        if (audioSessionConnection) {
            [session removeConnection:audioSessionConnection];
        }

        if (audioSessionOutput) {
            [session removeOutput:audioSessionOutput];
        }

        if (audioSessionInput) {
            [session removeInput:audioSessionInput];
        }
    }

    audioSessionConnection = nil;
    audioSessionOutput = nil;
    audioSessionInput = nil;
    audioInputDevice = nil;
    session = nil;

    return;
}

- (BOOL)isRunning {
    return session.running;
}

@end

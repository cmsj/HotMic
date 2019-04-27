//
//  THMBackEndAVFCapture.h
//  HotMic
//
//  Created by Chris Jones on 27/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>

#import "THMBackEndBase.h"
#import "THMSingleton.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMBackEndAVFCapture : THMBackEndBase <AVCaptureAudioDataOutputSampleBufferDelegate> {
    AVCaptureDevice *audioInputDevice;
    AVCaptureDeviceInput *audioSessionInput;
    AVCaptureAudioPreviewOutput *audioSessionOutput;
    AVCaptureConnection *audioSessionConnection;
    AVCaptureSession *session;
}

- (void)cleanupAVSession;

@end

NS_ASSUME_NONNULL_END

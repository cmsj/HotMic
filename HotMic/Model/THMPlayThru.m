//
//  THMPlayThru.m
//  HotMic
//
//  Created by Chris Jones on 03/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMPlayThru.h"
#import "THMLogging.h"

@implementation THMPlayThru

// FIXME: NOTHING IN HERE IS CHECKING ERRORS ZOMG

- (id)initWithInputDevice:(THMAudioDevice *)input andOutputDevice:(THMAudioDevice *)output {
    self = [super init];
    if (self) {
        isUIVisible = NO;
        inputDevice = input;
        outputDevice = output;

        // We store these explicitly to avoid a dot-property lookup in OutputProc()
        inputDeviceID = input.ID;
        outputDeviceID = output.ID;
        [self setup];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.uiDidAppearObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.uiDidDisappearObserver];

    [self stop];

    delete mBuffer;
    mBuffer = 0;

    if (mInputBuffer) {
        for(UInt32 i = 0; i < mInputBuffer->mNumberBuffers; i++)
            free(mInputBuffer->mBuffers[i].mData);
        free(mInputBuffer);
        mInputBuffer = 0;
    }

    AudioUnitUninitialize(mInputUnit);
    AUGraphClose(mGraph);
    DisposeAUGraph(mGraph);
    AudioComponentInstanceDispose(mInputUnit);
}

- (void)setup {
    OSStatus err = noErr;

    [self setupAUHAL];
    [self setupGraph];
    [self SetupBuffers];

    err = AUGraphConnectNodeInput(mGraph, mVarispeedNode, 0, mOutputNode, 0);
    checkErr(err);
    err = AUGraphInitialize(mGraph);
    checkErr(err);
    
    [self computeThruOffset];

    __weak THMPlayThru *weakself = self;
    self.uiDidAppearObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"THMUIDidAppear" object:nil queue:nil usingBlock:^(NSNotification *notification) {
        THMPlayThru *playThru = weakself;
        if (playThru) {
            playThru->isUIVisible = YES;
        }
    }];
    self.uiDidDisappearObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"THMUIDidDisappear" object:nil queue:nil usingBlock:^(NSNotification *notification) {
        THMPlayThru *playThru = weakself;
        if (playThru) {
            playThru->isUIVisible = NO;
            playThru->lastAmplitude = 0.0;
        }
    }];
}

- (BOOL)start {
    if ([self isRunning]) {
        return YES;
    }
    OSStatus err = noErr;

    //NSLog(@"Starting THMPlayThru");
    err = AudioOutputUnitStart(mInputUnit);
    checkErr(err);
    err = AUGraphStart(mGraph);
    checkErr(err);
    mFirstInputTime = -1;
    mFirstOutputTime = -1;

    return YES;
}

- (BOOL)stop {
    if (![self isRunning]) {
        return YES;
    }
    AudioOutputUnitStop(mInputUnit);
    AUGraphStop(mGraph);
    mFirstInputTime = -1;
    mFirstOutputTime = -1;

    lastAmplitude = 0.0;

    return YES;
}

- (BOOL)isRunning {
    OSStatus err = noErr;
    UInt32 auhalRunning = 0, size = 0;
    Boolean graphRunning = false;
    size = sizeof(auhalRunning);
    if(mInputUnit)
    {
        err = AudioUnitGetProperty(mInputUnit,
                                   kAudioOutputUnitProperty_IsRunning,
                                   kAudioUnitScope_Global,
                                   0, // input element
                                   &auhalRunning,
                                   &size);
        checkErr(err);
    }

    if(mGraph) {
        err = AUGraphIsRunning(mGraph,&graphRunning);
        checkErr(err);
    }

    return (auhalRunning || graphRunning);
}

- (BOOL)setInputDeviceAsCurrent {
    OSStatus err = noErr;

    UInt32 mID = inputDevice.ID;

    //Set the Current Device to the AUHAL.
    //this should be done only after IO has been enabled on the AUHAL.
    err = AudioUnitSetProperty(mInputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &mID,
                               sizeof(mID));
    checkErr(err);
    return err == noErr;
}

- (BOOL)setOutputDeviceAsCurrent {
    OSStatus err = noErr;

    UInt32 mID = outputDevice.ID;

    //Set the Current Device to the Default Output Unit.
    err = AudioUnitSetProperty(mOutputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &mID,
                               sizeof(mID));
    checkErr(err);
    return err == noErr;
}

- (BOOL)setupGraph {
    OSStatus err = noErr;
    AURenderCallbackStruct output;

    //Make a New Graph
    err = NewAUGraph(&mGraph);
    checkErr(err);

    //Open the Graph, AudioUnits are opened but not initialized
    err = AUGraphOpen(mGraph);
    checkErr(err);

    [self makeGraph];

    [self setOutputDeviceAsCurrent];

    //Tell the output unit not to reset timestamps
    //Otherwise sample rate changes will cause sync los
    UInt32 startAtZero = 0;
    err = AudioUnitSetProperty(mOutputUnit,
                               kAudioOutputUnitProperty_StartTimestampsAtZero,
                               kAudioUnitScope_Global,
                               0,
                               &startAtZero,
                               sizeof(startAtZero));
    checkErr(err);

    output.inputProc = OutputProc;
    output.inputProcRefCon = (__bridge void*)self;

    err = AudioUnitSetProperty(mVarispeedUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &output,
                               sizeof(output));
    checkErr(err);

    return err == noErr;
}

- (BOOL)makeGraph {
    OSStatus err = noErr;
    AudioComponentDescription varispeedDesc,outDesc;

    //Q:Why do we need a varispeed unit?
    //A:If the input device and the output device are running at different sample rates
    //we will need to move the data coming to the graph slower/faster to avoid a pitch change.
    varispeedDesc.componentType = kAudioUnitType_FormatConverter;
    varispeedDesc.componentSubType = kAudioUnitSubType_Varispeed;
    varispeedDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    varispeedDesc.componentFlags = 0;
    varispeedDesc.componentFlagsMask = 0;

    outDesc.componentType = kAudioUnitType_Output;
    outDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
    outDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outDesc.componentFlags = 0;
    outDesc.componentFlagsMask = 0;

    //////////////////////////
    ///MAKE NODES
    //This creates a node in the graph that is an AudioUnit, using
    //the supplied ComponentDescription to find and open that unit
    err = AUGraphAddNode(mGraph, &varispeedDesc, &mVarispeedNode);
    checkErr(err);
    err = AUGraphAddNode(mGraph, &outDesc, &mOutputNode);
    checkErr(err);

    //Get Audio Units from AUGraph node
    err = AUGraphNodeInfo(mGraph, mVarispeedNode, NULL, &mVarispeedUnit);
    checkErr(err);
    err = AUGraphNodeInfo(mGraph, mOutputNode, NULL, &mOutputUnit);
    checkErr(err);

    // don't connect nodes until the varispeed unit has input and output formats set

    return err == noErr;
}

- (BOOL)setupAUHAL {
    OSStatus err = noErr;
    //NSLog(@"setupAUHAL");

    AudioComponent comp;
    AudioComponentDescription desc;

    //There are several different types of Audio Units.
    //Some audio units serve as Outputs, Mixers, or DSP
    //units. See AUComponent.h for listing
    desc.componentType = kAudioUnitType_Output;

    //Every Component has a subType, which will give a clearer picture
    //of what this components function will be.
    desc.componentSubType = kAudioUnitSubType_HALOutput;

    //all Audio Units in AUComponent.h must use
    //"kAudioUnitManufacturer_Apple" as the Manufacturer
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    //Finds a component that meets the desc spec's
    comp = AudioComponentFindNext(NULL, &desc);
    if (comp == NULL) exit (-1); // FIXME: exit() here is unhelpful, return NO and bail out in the calling method

    //gains access to the services provided by the component
    err = AudioComponentInstanceNew(comp, &mInputUnit);
    checkErr(err);

    //AUHAL needs to be initialized before anything is done to it
    err = AudioUnitInitialize(mInputUnit);
    checkErr(err);

    [self enableIO];

    [self setInputDeviceAsCurrent];

    [self CallbackSetup];

    //Don't setup buffers until you know what the
    //input and output device audio streams look like.

    err = AudioUnitInitialize(mInputUnit);
    checkErr(err);

    return err == noErr;
}

- (BOOL)enableIO {
    OSStatus err = noErr;
    UInt32 enableIO;

    //NSLog(@"enableIO");

    ///////////////
    //ENABLE IO (INPUT)
    //You must enable the Audio Unit (AUHAL) for input and disable output
    //BEFORE setting the AUHAL's current device.

    //Enable input on the AUHAL
    enableIO = 1;
    err =  AudioUnitSetProperty(mInputUnit,
                                kAudioOutputUnitProperty_EnableIO,
                                kAudioUnitScope_Input,
                                1, // input element
                                &enableIO,
                                sizeof(enableIO));
    checkErr(err);

    //disable Output on the AUHAL
    enableIO = 0;
    err = AudioUnitSetProperty(mInputUnit,
                               kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Output,
                               0,   //output element
                               &enableIO,
                               sizeof(enableIO));
    checkErr(err);

    return err == noErr;
}

- (BOOL)CallbackSetup {
    OSStatus err = noErr;
    AURenderCallbackStruct input;
    //NSLog(@"CallbackSetup");

    input.inputProc = InputProc;
    input.inputProcRefCon = (__bridge void*)self;

    //Setup the input callback.
    err = AudioUnitSetProperty(mInputUnit,
                               kAudioOutputUnitProperty_SetInputCallback,
                               kAudioUnitScope_Global,
                               0,
                               &input,
                               sizeof(input));
    checkErr(err);
    return err == noErr;
}

- (BOOL)SetupBuffers {
    OSStatus err = noErr;
    UInt32 bufferSizeFrames,bufferSizeBytes,propsize;
    //NSLog(@"SetupBuffers");

    CAStreamBasicDescription asbd,asbd_dev1_in,asbd_dev2_out;
    Float64 rate=0;

    //Get the size of the IO buffer(s)
    UInt32 propertySize = sizeof(bufferSizeFrames);
    err = AudioUnitGetProperty(mInputUnit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &bufferSizeFrames, &propertySize);
    checkErr(err);
    bufferSizeBytes = bufferSizeFrames * sizeof(Float32);

    //Get the Stream Format (Output client side)
    propertySize = sizeof(asbd_dev1_in);
    err = AudioUnitGetProperty(mInputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &asbd_dev1_in, &propertySize);
    checkErr(err);
    printf("=====Input DEVICE stream format\n" );
    asbd_dev1_in.Print();

    //Get the Stream Format (client side)
    propertySize = sizeof(asbd);
    err = AudioUnitGetProperty(mInputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, &propertySize);
    checkErr(err);
    printf("=====current Input (Client) stream format\n");
    asbd.Print();

    //Get the Stream Format (Output client side)
    propertySize = sizeof(asbd_dev2_out);
    err = AudioUnitGetProperty(mOutputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd_dev2_out, &propertySize);
    checkErr(err);
    printf("=====Output (Device) stream format\n");
    asbd_dev2_out.Print();

    //////////////////////////////////////
    //Set the format of all the AUs to the input/output devices channel count
    //For a simple case, you want to set this to the lower of count of the channels
    //in the input device vs output device
    //////////////////////////////////////
    asbd.mChannelsPerFrame =((asbd_dev1_in.mChannelsPerFrame < asbd_dev2_out.mChannelsPerFrame) ?asbd_dev1_in.mChannelsPerFrame :asbd_dev2_out.mChannelsPerFrame) ;
    printf("Info: Input Device channel count=%u\t Output Device channel count=%u\n",(unsigned int)asbd_dev1_in.mChannelsPerFrame,(unsigned int)asbd_dev2_out.mChannelsPerFrame);
    printf("Info: CAPlayThrough will use %u channels\n",(unsigned int)asbd.mChannelsPerFrame);


    // We must get the sample rate of the input device and set it to the stream format of AUHAL
    propertySize = sizeof(Float64);
    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyNominalSampleRate,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster };

    err = AudioObjectGetPropertyData(inputDevice.ID, &theAddress, 0, NULL, &propertySize, &rate);
    checkErr(err);

    asbd.mSampleRate =rate;
    propertySize = sizeof(asbd);

    //Set the new formats to the AUs...
    err = AudioUnitSetProperty(mInputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, propertySize);
    checkErr(err);
    printf("=====current Input (Client) stream format\n");
    asbd.Print();
    err = AudioUnitSetProperty(mVarispeedUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, propertySize);
    checkErr(err);

    //Set the correct sample rate for the output device, but keep the channel count the same
    propertySize = sizeof(Float64);

    err = AudioObjectGetPropertyData(outputDevice.ID, &theAddress, 0, NULL, &propertySize, &rate);
    checkErr(err);

    asbd.mSampleRate =rate;
    propertySize = sizeof(asbd);

    //Set the new audio stream formats for the rest of the AUs...
    err = AudioUnitSetProperty(mVarispeedUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, propertySize);
    checkErr(err);
    err = AudioUnitSetProperty(mOutputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, propertySize);
    checkErr(err);

    //calculate number of buffers from channels
    propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) *asbd.mChannelsPerFrame);

    //malloc buffer lists
    mInputBuffer = (AudioBufferList *)malloc(propsize);
    mInputBuffer->mNumberBuffers = asbd.mChannelsPerFrame;

    //pre-malloc buffers for AudioBufferLists
    for(UInt32 i =0; i< mInputBuffer->mNumberBuffers ; i++) {
        mInputBuffer->mBuffers[i].mNumberChannels = 1;
        mInputBuffer->mBuffers[i].mDataByteSize = bufferSizeBytes;
        mInputBuffer->mBuffers[i].mData = malloc(bufferSizeBytes);
    }

    //Alloc ring buffer that will hold data between the two audio devices
    mBuffer = new CARingBuffer();
    mBuffer->Allocate(asbd.mChannelsPerFrame, asbd.mBytesPerFrame, bufferSizeFrames * 20);

    return err == noErr;

}

- (void)computeThruOffset {
    //The initial latency will at least be the saftey offset's of the devices + the buffer sizes
    // FIXME: double check that our bufferSize property matches the original mBufferSizeFrames property from CAPlayThrough::AudioDevice::
    mInToOutSampleOffset = SInt32(inputDevice.safetyOffset +  inputDevice.bufferSize +
                                  outputDevice.safetyOffset + outputDevice.bufferSize);
    NSLog(@"computeThruOffset: %d + %d + %d + %d = %f", inputDevice.safetyOffset, inputDevice.bufferSize, outputDevice.safetyOffset, outputDevice.bufferSize, mInToOutSampleOffset);
}

@end

#pragma mark -
#pragma mark -- IO Procs --
OSStatus InputProc(void *inRefCon,
                   AudioUnitRenderActionFlags *ioActionFlags,
                   const AudioTimeStamp *inTimeStamp,
                   UInt32 inBusNumber,
                   UInt32 inNumberFrames,
                   AudioBufferList * ioData)
{
    OSStatus err = noErr;

    //printf("InputProc called\n");
    THMPlayThru *This = (__bridge THMPlayThru *)inRefCon;
    if (This->mFirstInputTime < 0.)
        This->mFirstInputTime = inTimeStamp->mSampleTime;

    //Get the new audio data
    //printf("Reading %d frames for %f\n", inNumberFrames, inTimeStamp->mSampleTime);
    err = AudioUnitRender(This->mInputUnit,
                          ioActionFlags,
                          inTimeStamp,
                          inBusNumber,
                          inNumberFrames, //# of frames requested
                          This->mInputBuffer);// Audio Buffer List to hold data
    checkErr(err);

    if(!err && This->isUIVisible) {
        // Calculate audio sample amplitude for the UI metering
        Float32 *samples = (Float32*)(This->mInputBuffer->mBuffers[0].mData);
        Float32 peakValue = 0.0;
        for (int i = 0; i < inNumberFrames; i++) {
            Float32 absoluteValueOfSampleAmplitude = abs(samples[i]);
            if (absoluteValueOfSampleAmplitude > peakValue) {
                peakValue = absoluteValueOfSampleAmplitude;
            }
        }
        //printf("decibel: %f\n", peakValue);
        This->lastAmplitude = peakValue;
    }

    if (!err) {
        err = This->mBuffer->Store(This->mInputBuffer, Float64(inNumberFrames), SInt64(inTimeStamp->mSampleTime));
    }

    return err;
}

inline void MakeBufferSilent (AudioBufferList * ioData)
{
    for(UInt32 i=0; i<ioData->mNumberBuffers;i++)
        memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
}

OSStatus OutputProc(void *inRefCon,
                    AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp *TimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                    AudioBufferList * ioData)
{
    OSStatus err = noErr;
    THMPlayThru *This = (__bridge THMPlayThru *)inRefCon;
    Float64 rate = 0.0;
    AudioTimeStamp inTS, outTS;
    //printf("OutputProc called\n");
    if (This->mFirstInputTime < 0.) {
        // input hasn't run yet -> silence
        //printf("OutputProc: no input yet, outputting silence\n");
        MakeBufferSilent (ioData);
        return noErr;
    }

    //use the varispeed playback rate to offset small discrepancies in sample rate
    //first find the rate scalars of the input and output devices
    err = AudioDeviceGetCurrentTime(This->inputDeviceID, &inTS);
    checkErr(err);
    // this callback may still be called a few times after the device has been stopped
    if (err)
    {
        MakeBufferSilent (ioData);
        return noErr;
    }

    err = AudioDeviceGetCurrentTime(This->outputDeviceID, &outTS);
    checkErr(err);

    rate = inTS.mRateScalar / outTS.mRateScalar;
    err = AudioUnitSetParameter(This->mVarispeedUnit,kVarispeedParam_PlaybackRate,kAudioUnitScope_Global,0, rate,0);
    checkErr(err);

    //get Delta between the devices and add it to the offset
    if (This->mFirstOutputTime < 0.) {
        This->mFirstOutputTime = TimeStamp->mSampleTime;
        Float64 delta = (This->mFirstInputTime - This->mFirstOutputTime);
        [This computeThruOffset];
        //changed: 3865519 11/10/04
        if (delta < 0.0)
            This->mInToOutSampleOffset -= delta;
        else
            This->mInToOutSampleOffset = -delta + This->mInToOutSampleOffset;

        MakeBufferSilent (ioData);
        return noErr;
    }

    //copy the data from the buffers
    //printf("Writing %d frames for %f\n", inNumberFrames, TimeStamp->mSampleTime);
    err = This->mBuffer->Fetch(ioData, inNumberFrames, SInt64(TimeStamp->mSampleTime - This->mInToOutSampleOffset));
    if(err != kCARingBufferError_OK)
    {
        MakeBufferSilent (ioData);
        SInt64 bufferStartTime, bufferEndTime;
        This->mBuffer->GetTimeBounds(bufferStartTime, bufferEndTime);
        This->mInToOutSampleOffset = TimeStamp->mSampleTime - bufferStartTime;
    }

    return noErr;
}

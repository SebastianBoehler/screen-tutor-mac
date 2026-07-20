#import "SharedWebRTCAudioDevice.h"
#import <AVFAudio/AVFAudio.h>

@interface SharedWebRTCAudioDevice ()
@property(nonatomic, strong, nullable) id<RTCAudioDeviceDelegate> rtcDelegate;
@property(nonatomic, strong, nullable) AVAudioEngine *inputEngine;
@property(nonatomic, strong, nullable) AVAudioConverter *inputConverter;
@property(nonatomic, strong, nullable) AVAudioFormat *inputDeliveryFormat;
@property(nonatomic, strong, nullable) AVAudioEngine *outputEngine;
@property(nonatomic, strong, nullable) AVAudioSourceNode *outputSource;
@property(nonatomic) BOOL recordingInitialized;
@property(nonatomic) BOOL playoutInitialized;
@property(nonatomic) BOOL recording;
@property(nonatomic) BOOL playing;
@end

@implementation SharedWebRTCAudioDevice

- (BOOL)isInitialized {
    return self.rtcDelegate != nil;
}

- (BOOL)initializeWithDelegate:(id<RTCAudioDeviceDelegate>)delegate {
    if (self.rtcDelegate != nil) {
        return YES;
    }
    self.rtcDelegate = delegate;
    return YES;
}

- (BOOL)terminateDevice {
    [self stopRecording];
    [self stopPlayout];
    self.inputConverter = nil;
    self.inputDeliveryFormat = nil;
    self.inputEngine = nil;
    self.outputSource = nil;
    self.outputEngine = nil;
    self.recordingInitialized = NO;
    self.playoutInitialized = NO;
    self.rtcDelegate = nil;
    return YES;
}

- (double)deviceInputSampleRate {
    return self.rtcDelegate.preferredInputSampleRate ?: 48000.0;
}

- (NSTimeInterval)inputIOBufferDuration {
    return self.rtcDelegate.preferredInputIOBufferDuration ?: 0.01;
}

- (NSInteger)inputNumberOfChannels {
    return 1;
}

- (NSTimeInterval)inputLatency {
    return self.inputEngine.inputNode.presentationLatency;
}

- (double)deviceOutputSampleRate {
    return self.rtcDelegate.preferredOutputSampleRate ?: 48000.0;
}

- (NSTimeInterval)outputIOBufferDuration {
    return self.rtcDelegate.preferredOutputIOBufferDuration ?: 0.01;
}

- (NSInteger)outputNumberOfChannels {
    return 1;
}

- (NSTimeInterval)outputLatency {
    return self.outputEngine.outputNode.presentationLatency;
}

- (BOOL)isRecordingInitialized {
    return self.recordingInitialized;
}

- (BOOL)isRecording {
    return self.recording;
}

- (BOOL)initializeRecording {
    if (self.recordingInitialized) {
        return YES;
    }
    AVAudioEngine *engine = [[AVAudioEngine alloc] init];
    AVAudioFormat *deviceFormat = [engine.inputNode outputFormatForBus:0];
    if (deviceFormat.sampleRate <= 0 || deviceFormat.channelCount == 0) {
        return NO;
    }
    AVAudioFormat *deliveryFormat = [[AVAudioFormat alloc]
        initWithCommonFormat:AVAudioPCMFormatInt16
        sampleRate:self.deviceInputSampleRate
        channels:1
        interleaved:YES];
    AVAudioConverter *converter = [[AVAudioConverter alloc]
        initFromFormat:deviceFormat
        toFormat:deliveryFormat];
    if (converter == nil) {
        return NO;
    }
    self.inputEngine = engine;
    self.inputConverter = converter;
    self.inputDeliveryFormat = deliveryFormat;
    self.recordingInitialized = YES;
    return YES;
}

- (BOOL)startRecording {
    if (self.recording) {
        return YES;
    }
    if (![self initializeRecording]) {
        return NO;
    }
    AVAudioEngine *engine = self.inputEngine;
    AVAudioInputNode *inputNode = engine.inputNode;
    AVAudioFormat *deviceFormat = [inputNode outputFormatForBus:0];
    AVAudioFrameCount frameCount = (AVAudioFrameCount)lrint(
        deviceFormat.sampleRate * self.inputIOBufferDuration
    );
    __weak typeof(self) weakSelf = self;
    [inputNode installTapOnBus:0
                   bufferSize:MAX(frameCount, 128)
                       format:deviceFormat
                        block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        [weakSelf deliverInputBuffer:buffer atTime:when];
    }];
    [engine prepare];
    NSError *error = nil;
    if (![engine startAndReturnError:&error]) {
        [inputNode removeTapOnBus:0];
        return NO;
    }
    self.recording = YES;
    return YES;
}

- (BOOL)stopRecording {
    if (!self.recording) {
        return YES;
    }
    [self.inputEngine.inputNode removeTapOnBus:0];
    [self.inputEngine stop];
    [self.inputEngine reset];
    self.recording = NO;
    return YES;
}

- (void)deliverInputBuffer:(AVAudioPCMBuffer *)input atTime:(AVAudioTime *)when {
    AVAudioConverter *converter = self.inputConverter;
    AVAudioFormat *format = self.inputDeliveryFormat;
    id<RTCAudioDeviceDelegate> rtcDelegate = self.rtcDelegate;
    if (converter == nil || format == nil || rtcDelegate == nil) {
        return;
    }
    double ratio = format.sampleRate / input.format.sampleRate;
    AVAudioFrameCount capacity = (AVAudioFrameCount)ceil(input.frameLength * ratio) + 64;
    AVAudioPCMBuffer *output = [[AVAudioPCMBuffer alloc]
        initWithPCMFormat:format
        frameCapacity:capacity];
    __block BOOL suppliedInput = NO;
    NSError *error = nil;
    AVAudioConverterOutputStatus status = [converter
        convertToBuffer:output
        error:&error
        withInputFromBlock:^AVAudioBuffer *_Nullable(
            AVAudioPacketCount packetCount,
            AVAudioConverterInputStatus *inputStatus
        ) {
            if (suppliedInput) {
                *inputStatus = AVAudioConverterInputStatus_NoDataNow;
                return nil;
            }
            suppliedInput = YES;
            *inputStatus = AVAudioConverterInputStatus_HaveData;
            return input;
        }];
    if (status == AVAudioConverterOutputStatus_Error || output.frameLength == 0) {
        return;
    }
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = when.audioTimeStamp;
    rtcDelegate.deliverRecordedData(
        &flags,
        &timestamp,
        0,
        output.frameLength,
        output.audioBufferList,
        NULL,
        nil
    );
}

- (BOOL)isPlayoutInitialized {
    return self.playoutInitialized;
}

- (BOOL)isPlaying {
    return self.playing;
}

- (BOOL)initializePlayout {
    if (self.playoutInitialized) {
        return YES;
    }
    AVAudioEngine *engine = [[AVAudioEngine alloc] init];
    AVAudioFormat *format = [[AVAudioFormat alloc]
        initWithCommonFormat:AVAudioPCMFormatInt16
        sampleRate:self.deviceOutputSampleRate
        channels:1
        interleaved:YES];
    __weak typeof(self) weakSelf = self;
    AVAudioSourceNode *source = [[AVAudioSourceNode alloc]
        initWithFormat:format
        renderBlock:^OSStatus(
            BOOL *isSilence,
            const AudioTimeStamp *timestamp,
            AVAudioFrameCount frameCount,
            AudioBufferList *outputData
        ) {
            id<RTCAudioDeviceDelegate> rtcDelegate = weakSelf.rtcDelegate;
            if (rtcDelegate == nil) {
                *isSilence = YES;
                return noErr;
            }
            *isSilence = NO;
            AudioUnitRenderActionFlags flags = 0;
            OSStatus status = rtcDelegate.getPlayoutData(
                &flags,
                timestamp,
                0,
                frameCount,
                outputData
            );
            if (status != noErr) {
                *isSilence = YES;
            }
            return status;
        }];
    [engine attachNode:source];
    [engine connect:source to:engine.mainMixerNode format:format];
    AVAudioFormat *deviceFormat = [engine.outputNode inputFormatForBus:0];
    if (deviceFormat.sampleRate <= 0 || deviceFormat.channelCount == 0) {
        return NO;
    }
    [engine connect:engine.mainMixerNode to:engine.outputNode format:deviceFormat];
    self.outputEngine = engine;
    self.outputSource = source;
    self.playoutInitialized = YES;
    return YES;
}

- (BOOL)startPlayout {
    if (self.playing) {
        return YES;
    }
    if (![self initializePlayout]) {
        return NO;
    }
    [self.outputEngine prepare];
    NSError *error = nil;
    if (![self.outputEngine startAndReturnError:&error]) {
        return NO;
    }
    self.playing = YES;
    return YES;
}

- (BOOL)stopPlayout {
    if (!self.playing) {
        return YES;
    }
    [self.outputEngine stop];
    [self.outputEngine reset];
    self.playing = NO;
    return YES;
}

@end

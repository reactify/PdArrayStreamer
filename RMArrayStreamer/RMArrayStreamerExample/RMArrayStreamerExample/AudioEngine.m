 //
//  AudioEngine.m
//  Tannhauser
//
//  Created by Joe White on 31/12/2013.
//  Copyright (c) 2013 Martin Roth. All rights reserved.
//

#import <stdio.h>
#import "AudioEngine.h"
#import "RMStreamingPlayer.h"

void printHook(double timestamp, const char *name, const char *s, void *v) {
	NSLog(@"[%g] %s: %s", timestamp, name, s);
}

static void checkError(OSStatus error, const char *operation) {
	if (error == noErr) return;
	
	char errorString[20] = {};
	// See if it appears to be a 4-char code
	*(UInt32 *)(errorString+1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) &&
		isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else {
		sprintf(errorString, "%d", (int)error);
	}
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);

	exit(1);
}


@interface AudioEngine ()

@property (nonatomic, copy) AudioEngineCallBackBlock block;

@end


@implementation AudioEngine

+ (instancetype)audioEngineWithBlock:(AudioEngineCallBackBlock)block
{
	AudioEngine *audioEngine = [AudioEngine new];
	audioEngine.block = block;
	return audioEngine;
}

OSStatus AudioEngineRenderProc(void *inRefCon,
							   AudioUnitRenderActionFlags *ioActionsFlags,
							   const AudioTimeStamp *inTimeStamp,
							   UInt32 inBusNumber,
							   UInt32 inNumberFrames,
							   AudioBufferList *ioData)
{
	AudioEngine *audioEngine = (__bridge AudioEngine *)inRefCon;
	
	if (audioEngine->_block) audioEngine->_block(inNumberFrames, ioData);
	
	return noErr;
}

- (id)init {
	self = [super init];
	if (self) {
		_sampleRate = 44100.0;
		_blockSize = 256;
		_counter = 0;
		
		[self initialiseAudioUnit];
	}
	return self;
}

- (void)initialiseAudioUnit {
	
	// Generate output audio unit
	AudioComponentDescription outputcd = {0};
	outputcd.componentType = kAudioUnitType_Output;
	outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
	outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	AudioComponent comp = AudioComponentFindNext(NULL, &outputcd);
	if (comp == NULL) {
		NSLog(@"Can't get output unit");
		exit(-1);
	}
	
	checkError(AudioComponentInstanceNew(comp, &_outputUnit),
			   "Couldn't open component for outputUnit");
	
	// Get stream format
	AudioStreamBasicDescription asbd = {0};
	UInt32 size = sizeof(asbd);
	checkError(AudioUnitGetProperty(_outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&asbd,
									&size),
			   "AudioUnitGetProperty (kAudioUnitProperty_StreamFormat) failed");
	
	// Set stream format
	asbd.mBytesPerPacket = 4;
	asbd.mFramesPerPacket = 1;
	asbd.mChannelsPerFrame = 2;
	asbd.mBitsPerChannel = 32;
	asbd.mFormatID = kAudioFormatLinearPCM;
	asbd.mFormatFlags = kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
	[self printStreamDescription:asbd];
	
	checkError(AudioUnitSetProperty(_outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&asbd,
									size),
			   "AudioUnitSetProperty (kAudioUnitProperty_StreamFormat) failed");
	
	// Register the render callback
	AURenderCallbackStruct input;
	input.inputProc = AudioEngineRenderProc;
	input.inputProcRefCon = (__bridge void *)(self);
	checkError(AudioUnitSetProperty(_outputUnit,
									kAudioUnitProperty_SetRenderCallback,
									kAudioUnitScope_Input,
									0,
									&input,
									sizeof(input)),
			   "AudioUnitSetProperty (kAudioUnitProperty_SetRenderCallback) failed");
	
	// Initialise the unit
	checkError(AudioUnitInitialize(_outputUnit),
			   "Couldn't initialise outut unit");
	
	_sampleRate = asbd.mSampleRate;
}

- (void)start {
	checkError(AudioOutputUnitStart(_outputUnit),
			   "Couldn't start output unit");
}

- (void)stop {
	checkError(AudioOutputUnitStop(_outputUnit),
			   "Couldn't stop output unit");
}

- (void)destroy {
	AudioOutputUnitStop(_outputUnit);
	AudioUnitUninitialize(_outputUnit);
	AudioComponentInstanceDispose(_outputUnit);
}

- (void)printStreamDescription:(const AudioStreamBasicDescription)asbd {
	NSLog(@"AudioStreamBasicDescription:");
	NSLog(@"\t Sample Rate:\t\t %g", asbd.mSampleRate);
	NSLog(@"\t Bytes Per Packet:\t %d", asbd.mBytesPerPacket);
	NSLog(@"\t Frames Per Packet:\t %d", asbd.mFramesPerPacket);
	NSLog(@"\t Channels Per Frame: %d", asbd.mChannelsPerFrame);
	NSLog(@"\t Bits Per Channel:\t %d", asbd.mBitsPerChannel);
	
	char formatID[20] = {};
	*(UInt32 *)(formatID+1) = CFSwapInt32HostToBig(asbd.mFormatID);
	if (isprint(formatID[1]) && isprint(formatID[2]) &&
		isprint(formatID[3]) && isprint(formatID[4])) {
		formatID[0] = formatID[5] = '\'';
		formatID[6] = '\0';
		NSLog(@"\t Format ID:\t\t\t %s", formatID);
	}
	else {
		NSLog(@"\t Format ID:\t\t\t unknown");
	}
	
	NSLog(@"\t Format Flags:");
	if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) NSLog(@"\t\t kAudioFormatFlagIsFloat");
	if (asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) NSLog(@"\t\t kAudioFormatFlagIsBigEndian");
	if (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) NSLog(@"\t\t kAudioFormatFlagIsSignedInteger");
	if (asbd.mFormatFlags & kAudioFormatFlagIsPacked) NSLog(@"\t\t kAudioFormatFlagIsPacked");
	if (asbd.mFormatFlags & kAudioFormatFlagIsAlignedHigh) NSLog(@"\t\t kAudioFormatFlagIsAlignedHigh");
	if (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) NSLog(@"\t\t kAudioFormatFlagIsNonInterleaved");
	if (asbd.mFormatFlags & kAudioFormatFlagIsNonMixable) NSLog(@"\t\t kAudioFormatFlagIsNonMixable");
	if (asbd.mFormatFlags & kAudioFormatFlagIsNonMixable) NSLog(@"\t\t kAudioFormatFlagsAreAllClear");
}

+ (void)dumpBufferToFile:(NSString *)path buffer:(float *)data numSamples:(int)num
{
	FILE *outputFile = fopen([[path stringByExpandingTildeInPath] UTF8String], "w");
	if (outputFile == NULL) {
		NSLog(@"Error opening file %@", path);
		exit(1);
	}
	for (int i = 0; i < num; i++)
	{
		fprintf(outputFile, "%f  %f\n", (float)i/num, data[i]);
	}
	fclose(outputFile);
}

@end

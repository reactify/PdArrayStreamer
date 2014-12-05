//
//  RMArrayStreamer.m
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

// http://stackoverflow.com/questions/6242131/using-avassetreader-to-read-stream-from-a-remote-asset

#import <Accelerate/Accelerate.h>

#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetTrack.h>
#import <AVFoundation/AVAssetReader.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVAudioSettings.h>
#import <AVFoundation/AVAssetReaderOutput.h>

#import "RMArrayStreamer.h"


@interface RMArrayStreamer ()

@property (nonatomic, strong, readonly) AVAssetReader *assetReader;

@end


@implementation RMArrayStreamer

- (instancetype)initWithArraySize:(int)arraySize // Note: Maximum 2 channels
{
	self = [super init];
	if (!self) return nil;
	
	_arraySize = arraySize;
	totalDecompressedFrames = 0;
	numDecompressedFrames = 0;
	_decompressCallback = nil;
	
	return self;
}

- (void)dealloc
{
	_assetReader = nil;
	_decompressCallback = nil;
	
	if (_leftBuffer)  free(_leftBuffer);
	if (_rightBuffer) free(_rightBuffer);
}

- (void)continueDecompression
{
	dispatch_async_f(dispatch_get_main_queue(), (__bridge void *)(self), decompressLoop);
}

- (void)startDecompressingFromUrl:(NSURL *)fileUrl
		   withDecompressCallback:(void(^)(AVAssetReaderStatus status, int numDecompressedFrames))block
{
	NSError *error = nil;

	_decompressCallback = block;

	// create the AVAsset
	AVAsset *avAsset = [AVURLAsset URLAssetWithURL:fileUrl options:nil];

	// get the number of channels (and other stream descriptors)
	NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];
	if (tracks.count == 0)
	{
		NSLog(@"Error - couldn't read from audio file %@", fileUrl);
		return;
	}
	
	AVAssetTrack *assetTrack = [tracks objectAtIndex:0];
	
	const CMFormatDescriptionRef formatDescr = (__bridge CMFormatDescriptionRef) [assetTrack.formatDescriptions objectAtIndex:0];
	const AudioStreamBasicDescription *basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescr);
	_channelCount = basicDescription->mChannelsPerFrame;
	
	// Initialise float buffers
	if (_leftBuffer)  free(_leftBuffer);
	if (_rightBuffer) free(_rightBuffer);
	_leftBuffer  = (float *)malloc(_arraySize * sizeof(float));
	_rightBuffer = (float *)malloc(_arraySize * sizeof(float));

	// create the AVAssetReader
	_assetReader = [AVAssetReader assetReaderWithAsset:avAsset error:&error];
	if (!_assetReader)
	{
		NSLog(@"Error initialising Asset Reader: %@", error);
		return;
	}
	
	numDecompressedFrames = 0;

	// decode the asset to kAudioFormatLinearPCM, Pd's sampleRate, 16bit, interleaved
	_sampleRate = 44100.0f;

	NSMutableDictionary *outputSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										   @(kAudioFormatLinearPCM), AVFormatIDKey,
										   @(_sampleRate), AVSampleRateKey,
										   @(16), AVLinearPCMBitDepthKey,
										   @(NO), AVLinearPCMIsFloatKey,
										   @(NO), AVLinearPCMIsBigEndianKey,
										   @(NO), AVLinearPCMIsNonInterleaved,
										   nil];

	// tell the AVAssetReader which output track it should decode
	AVAssetReaderOutput *assetReaderOutput
	= [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[avAsset.tracks objectAtIndex:0]
												 outputSettings:outputSettings];
	[_assetReader addOutput:assetReaderOutput];

	// start reading!
	[_assetReader startReading];

	// start the decompress loop
	dispatch_async_f(dispatch_get_main_queue(),(__bridge void *)(self), decompressLoop);
}

- (void)stopDecompressing
{
	[_assetReader cancelReading];
	_assetReader = nil;
	
	if (_leftBuffer)  free(_leftBuffer);
	if (_rightBuffer) free(_rightBuffer);
}

void decompressLoop(void *context)
{
	RMArrayStreamer *arrayStreamer = (__bridge RMArrayStreamer *) context;
	switch (arrayStreamer->_assetReader.status)
	{
		case AVAssetReaderStatusReading:
		{
			AVAssetReaderTrackOutput *trackOutput =
			(AVAssetReaderTrackOutput *) [arrayStreamer->_assetReader.outputs objectAtIndex:0];
			
			// decompress the received frames
			CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
			if (sampleBufferRef == NULL) {
				arrayStreamer->_decompressCallback(AVAssetReaderStatusCompleted, arrayStreamer->numDecompressedFrames);
				return;
			}
			CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
			size_t length = CMBlockBufferGetDataLength(blockBufferRef); // number of decoded bytes
			char shortBuffer[length];
			CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, shortBuffer);
			CMSampleBufferInvalidate(sampleBufferRef);
			CFRelease(sampleBufferRef);
			if (length <= 0) return;
			
			// copy the frames into buffers
			const int numChannels = arrayStreamer->_channelCount;
			const int numFrames = (int)(length/sizeof(short)/numChannels);
			float floatBuffer[numFrames];
			const int offset = arrayStreamer->numDecompressedFrames;
			const float a = 0.000030517578125f;
			switch (numChannels)
			{
				default: break; // TODO(mhroth): handle channel counts other than 1 or 2
				case 2:
				{
					// convert the decompressed interleaved short samples to uninterleaved floats
					vDSP_vflt16(((short *) shortBuffer)+1, numChannels, floatBuffer, 1, numFrames);
					vDSP_vsmul(floatBuffer, 1, &a, floatBuffer, 1, numFrames);
					
					memcpy(arrayStreamer->_rightBuffer + offset, floatBuffer, numFrames * sizeof(float));
					
					// allow fallthrough
				}
				case 1:
				{
					vDSP_vflt16((short *) shortBuffer, numChannels, floatBuffer, 1, numFrames);
					vDSP_vsmul(floatBuffer, 1, &a, floatBuffer, 1, numFrames);
					
					memcpy(arrayStreamer->_leftBuffer + offset, floatBuffer, numFrames * sizeof(float));
				}
				case 0: break;
			}
			
			// increment the number of decompressed frames (i.e. increment the table offset)
			arrayStreamer->numDecompressedFrames   += numFrames;
			arrayStreamer->totalDecompressedFrames += numFrames;
			
			// if the next round of decompression does not overflow the table, schedule a new decompression
			// otherwise just wait to be triggered again
			if (arrayStreamer->numDecompressedFrames + numFrames <= arrayStreamer->_arraySize)
			{
				// wait a short period of time before continuing the decompression
				int64_t blockDurationSec = ((float) numFrames) / arrayStreamer->_sampleRate;
				dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.5 * blockDurationSec * NSEC_PER_SEC);
				dispatch_after_f(popTime, dispatch_get_main_queue(), context, decompressLoop);
			}
			else
			{
				arrayStreamer->_decompressCallback(AVAssetReaderStatusReading, arrayStreamer->numDecompressedFrames);
				arrayStreamer->numDecompressedFrames = 0; // reset the number of decompressed frames
			}
			break;
		}
		case AVAssetReaderStatusCompleted:
		{
			NSLog(@"AVAssetReaderStatusCompleted");
			arrayStreamer->_decompressCallback(AVAssetReaderStatusCompleted, arrayStreamer->numDecompressedFrames);
			return;
		}
		case AVAssetReaderStatusCancelled:
		{
			NSLog(@"AVAssetReaderStatusCancelled");
			arrayStreamer->_decompressCallback(AVAssetReaderStatusCancelled, arrayStreamer->numDecompressedFrames);
			return;
		}
		case AVAssetReaderStatusFailed: {
			NSLog(@"AVAssetReaderStatusFailed");
			arrayStreamer->_decompressCallback(AVAssetReaderStatusFailed, arrayStreamer->numDecompressedFrames);
			return;
		}
		default:
		case AVAssetReaderStatusUnknown:
		{
			NSLog(@"AVAssetReaderStatusUnknown");
			return;
		}
	}
}

@end

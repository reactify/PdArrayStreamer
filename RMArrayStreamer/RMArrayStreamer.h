//
//  RMArrayStreamer.h
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

#import <Foundation/NSObject.h>

@class NSURL;

enum {
	RMArrayStreamerStatusUnknown = 0,
	RMArrayStreamerStatusReading,
	RMArrayStreamerStatusCompleted,
	RMArrayStreamerStatusFailed,
	RMArrayStreamerStatusCancelled,
};
typedef NSInteger RMArrayStreamerStatus;

typedef void (^RMArrayStreamerDecompressCallback)(RMArrayStreamerStatus status,
												  int numDecompressedFrames);

@interface RMArrayStreamer : NSObject
{
@public
	int numDecompressedFrames; // the number of frames decompressed for this portion of the array
	int totalDecompressedFrames; // the total number of frames ever decompressed

	float *_leftBuffer;
	float *_rightBuffer;
}

@property (nonatomic, assign, readonly) float sampleRate;
@property (nonatomic, assign, readonly) int channelCount;
@property (nonatomic, assign, readonly) int arraySize;      
@property (nonatomic,	copy, readonly) RMArrayStreamerDecompressCallback decompressCallback;

- (instancetype)initWithArraySize:(int)arraySize;
 
/**
* This method will space the decompression out in time, in order to reduce the immediate load on
* the main thread.
*/
- (void)startDecompressingFromUrl:(NSURL *)filePath
		   withDecompressCallback:(RMArrayStreamerDecompressCallback)block;

/**
* Call this method in order to continue the decompression into a limited size table.
*/
- (void)continueDecompression;

/**
 * Call this method in order to stop the decompression.
 */
- (void)stopDecompressing;

//- (void)clear;

@end
